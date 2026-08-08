import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../models/exceptions.dart';
import '../models/metadata.dart';

/// Fetches package metadata from a package repository (e.g. pub.dev).
abstract interface class PackageRepository {
  /// Returns metadata for [name].
  Future<PackageMetadata> getPackage(String name);
}

/// Default pub.dev [PackageRepository] with timeout, retry, and cache.
class PubDevRepository implements PackageRepository {
  /// Creates a pub.dev repository client.
  PubDevRepository({
    http.Client? client,
    this.baseUrl = 'https://pub.dev',
    this.timeout = const Duration(seconds: 12),
    this.maxRetries = 2,
    this.maxConcurrent = 6,
    Map<String, PackageMetadata>? cache,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _cache = cache ?? {};

  /// API base URL.
  final String baseUrl;

  /// Per-request timeout.
  final Duration timeout;

  /// Retry attempts after the first try.
  final int maxRetries;

  /// Max concurrent in-flight requests.
  final int maxConcurrent;

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, PackageMetadata> _cache;

  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  @override
  Future<PackageMetadata> getPackage(String name) async {
    final cached = _cache[name];
    if (cached != null) return cached;

    await _acquire();
    try {
      Object? lastError;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          final uri =
              Uri.parse('$baseUrl/api/packages/${Uri.encodeComponent(name)}');
          final response = await _client.get(uri).timeout(timeout);
          if (response.statusCode == 404) {
            throw PackageNotFoundException(name);
          }
          if (response.statusCode >= 500) {
            throw PackageRepositoryException(
              'Server error ${response.statusCode} fetching "$name".',
              package: name,
            );
          }
          if (response.statusCode != 200) {
            throw PackageRepositoryException(
              'Unexpected status ${response.statusCode} fetching "$name".',
              package: name,
            );
          }
          final metadata = _parse(name, jsonDecode(response.body));
          _cache[name] = metadata;
          return metadata;
        } on PackageNotFoundException {
          rethrow;
        } on TimeoutException catch (e) {
          lastError = e;
        } on http.ClientException catch (e) {
          lastError = e;
        } on PackageRepositoryException catch (e) {
          lastError = e;
          // Retry only server errors.
          if (!e.message.contains('Server error')) rethrow;
        }
        if (attempt < maxRetries) {
          await Future<void>.delayed(
              Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
      throw OfflineRepositoryException(package: name, cause: lastError);
    } finally {
      _release();
    }
  }

  /// Closes the underlying HTTP client when owned.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<void> _acquire() async {
    if (_inFlight < maxConcurrent) {
      _inFlight++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    _inFlight++;
  }

  void _release() {
    _inFlight--;
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }

  PackageMetadata _parse(String name, Object? json) {
    if (json is! Map) {
      throw PackageRepositoryException(
        'Invalid package metadata for "$name".',
        package: name,
      );
    }
    final map = <String, Object?>{
      for (final e in json.entries) e.key.toString(): e.value as Object?,
    };

    final latestRaw = map['latest'];
    Version? latest;
    Version? latestStable;
    final versions = <PackageVersionInfo>[];

    final versionsRaw = map['versions'];
    if (versionsRaw is List) {
      for (final item in versionsRaw) {
        if (item is! Map) continue;
        final info = _parseVersion({
          for (final e in item.entries) e.key.toString(): e.value as Object?,
        });
        if (info != null) versions.add(info);
      }
    }

    if (latestRaw is Map) {
      final latestMap = <String, Object?>{
        for (final e in latestRaw.entries) e.key.toString(): e.value as Object?,
      };
      final v = latestMap['version']?.toString();
      if (v != null) {
        try {
          latest = Version.parse(v);
        } on FormatException {
          // ignore
        }
      }
    }

    for (final info in versions) {
      if (info.retracted) continue;
      if (info.version.isPreRelease) continue;
      if (latestStable == null || info.version > latestStable) {
        latestStable = info.version;
      }
    }
    latestStable ??= latest;

    String? description;
    String? repository;
    String? homepage;
    if (latestRaw is Map) {
      final pubspec = latestRaw['pubspec'];
      if (pubspec is Map) {
        description = pubspec['description']?.toString();
        repository = pubspec['repository']?.toString();
        homepage = pubspec['homepage']?.toString();
      }
    }

    final isDiscontinued = map['isDiscontinued'] == true;
    final replacedBy = map['replacedBy']?.toString();
    final publisher =
        map['publisherId']?.toString() ?? map['publisher']?.toString();

    final notes = <String>[];
    if (isDiscontinued) {
      notes.add(
        replacedBy == null
            ? 'Marked discontinued on the package repository.'
            : 'Marked discontinued; replaced by "$replacedBy".',
      );
    }
    if (latest != null &&
        latestStable != null &&
        latest.isPreRelease &&
        latest > latestStable) {
      notes.add(
        'Newer versions exist only as pre-releases (latest $latest, '
        'latest stable $latestStable).',
      );
    }

    return PackageMetadata(
      name: name,
      versions: versions,
      latest: latest,
      latestStable: latestStable,
      description: description,
      isDiscontinued: isDiscontinued,
      replacedBy: replacedBy,
      repository: repository,
      homepage: homepage,
      publisher: publisher,
      factualNotes: notes,
    );
  }

  PackageVersionInfo? _parseVersion(Map<String, Object?> map) {
    final versionRaw = map['version']?.toString();
    if (versionRaw == null) return null;
    late final Version version;
    try {
      version = Version.parse(versionRaw);
    } on FormatException {
      return null;
    }

    DateTime? published;
    final publishedRaw = map['published']?.toString();
    if (publishedRaw != null) {
      published = DateTime.tryParse(publishedRaw);
    }

    final retracted = map['retracted'] == true;
    final pubspecRaw = map['pubspec'];
    VersionConstraint? sdk;
    VersionConstraint? flutter;
    final deps = <String, VersionConstraint>{};
    final devDeps = <String, VersionConstraint>{};

    if (pubspecRaw is Map) {
      final pubspec = <String, Object?>{
        for (final e in pubspecRaw.entries)
          e.key.toString(): e.value as Object?,
      };
      final envRaw = pubspec['environment'];
      if (envRaw is Map) {
        sdk = _tryConstraint(envRaw['sdk']);
        flutter = _tryConstraint(envRaw['flutter']);
      }
      _readDeps(pubspec['dependencies'], deps);
      _readDeps(pubspec['dev_dependencies'], devDeps);
    }

    return PackageVersionInfo(
      version: version,
      published: published,
      retracted: retracted,
      sdkConstraint: sdk,
      flutterConstraint: flutter,
      dependencies: deps,
      devDependencies: devDeps,
    );
  }

  void _readDeps(Object? raw, Map<String, VersionConstraint> out) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final value = entry.value;
      if (value is String) {
        final c = _tryConstraint(value);
        if (c != null) out[key] = c;
      } else if (value is Map && value['version'] != null) {
        final c = _tryConstraint(value['version']);
        if (c != null) out[key] = c;
      } else {
        out[key] = VersionConstraint.any;
      }
    }
  }

  VersionConstraint? _tryConstraint(Object? raw) {
    if (raw == null) return null;
    try {
      return VersionConstraint.parse(raw.toString());
    } on FormatException {
      return null;
    }
  }
}

/// In-memory [PackageRepository] for tests.
class FakePackageRepository implements PackageRepository {
  /// Creates a fake repository from a name→metadata map.
  FakePackageRepository(this.packages);

  /// Seeded packages.
  final Map<String, PackageMetadata> packages;

  @override
  Future<PackageMetadata> getPackage(String name) async {
    final meta = packages[name];
    if (meta == null) throw PackageNotFoundException(name);
    return meta;
  }
}
