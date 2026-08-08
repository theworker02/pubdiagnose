import 'dart:convert';

import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import 'package_event.dart';

/// Cached ecosystem metadata with timestamps and expiry.
class EcosystemCache {
  /// Creates a cache.
  EcosystemCache({
    required this.rootPath,
    required FilesystemAdapter fs,
    required PathAdapter paths,
    this.ttl = const Duration(hours: 24),
  })  : _fs = fs,
        _paths = paths;

  /// Cache root directory.
  final String rootPath;

  /// TTL for entries.
  final Duration ttl;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  String _pathFor(String package) =>
      _paths.join(rootPath, 'ecosystem', '$package.json');

  /// Ensure layout.
  void ensureLayout() {
    _fs.createDirectory(_paths.join(rootPath, 'ecosystem'));
  }

  /// Read last-known entry if present (even if expired).
  Map<String, Object?>? read(String package) {
    final path = _pathFor(package);
    final text = _fs.readText(path);
    if (text == null) return null;
    try {
      final raw = jsonDecode(text);
      if (raw is! Map) return null;
      return Map<String, Object?>.from(raw.cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  /// Whether cached entry is still fresh.
  bool isFresh(Map<String, Object?> entry) {
    final at = entry['cachedAt']?.toString();
    if (at == null) return false;
    try {
      final ts = DateTime.parse(at);
      return DateTime.now().toUtc().difference(ts) <= ttl;
    } on Object {
      return false;
    }
  }

  /// Write entry.
  void write(String package, Map<String, Object?> data) {
    ensureLayout();
    final payload = {
      ...data,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
    };
    _fs.writeText(_pathFor(package), '${jsonEncode(payload)}\n');
  }
}

/// Observes public ecosystem metadata (online) with offline last-known.
class EcosystemObserver {
  /// Creates an observer.
  EcosystemObserver({
    this.cache,
    this.offline = false,
    Future<Map<String, Object?>?> Function(String package)? fetchMetadata,
  }) : _fetch = fetchMetadata;

  /// Optional durable cache.
  final EcosystemCache? cache;

  /// Offline mode.
  final bool offline;

  final Future<Map<String, Object?>?> Function(String package)? _fetch;

  /// Observe workspace packages (overview).
  Future<Map<String, Object?>> overview({
    required Map<String, String> projectVersions,
  }) async {
    final packages = <Map<String, Object?>>[];
    for (final e in projectVersions.entries.take(40)) {
      packages.add(await packageStatus(e.key, currentVersion: e.value));
    }
    return {
      'command': 'ecosystem',
      'offline': offline,
      'packageCount': packages.length,
      'packages': packages,
    };
  }

  /// Status for one package.
  Future<Map<String, Object?>> packageStatus(
    String package, {
    String? currentVersion,
  }) async {
    Map<String, Object?>? meta;
    var source = 'none';
    var stale = false;

    if (!offline && _fetch != null) {
      try {
        meta = await _fetch(package);
        if (meta != null) {
          source = 'live';
          cache?.write(package, meta);
        }
      } on Object {
        meta = null;
      }
    }

    if (meta == null) {
      final cached = cache?.read(package);
      if (cached != null) {
        meta = cached;
        source = 'last-known';
        stale = !(cache?.isFresh(cached) ?? false);
      }
    }

    final latest =
        meta?['latest']?.toString() ?? meta?['latestVersion']?.toString();
    final discontinued = meta?['discontinued'] == true;
    final replacement = meta?['replacedBy']?.toString();

    final events = <PackageEvent>[];
    final signals = <ObservatoryCompatibilitySignal>[];
    final deprecations = <DeprecationSignal>[];
    final recent = <String>[];

    if (discontinued) {
      events.add(
        PackageEvent(
          package: package,
          kind: PackageEventKind.discontinued,
          summary: 'Package marked discontinued in metadata',
        ),
      );
      deprecations.add(
        DeprecationSignal(
          package: package,
          summary: 'Package appears discontinued',
          replacement: replacement,
        ),
      );
    }

    if (latest != null && currentVersion != null && latest != currentVersion) {
      recent
          .add('Latest known version is $latest (project has $currentVersion)');
      // Cautious forecast language — never certainty.
      signals.add(
        ObservatoryCompatibilitySignal(
          package: package,
          summary:
              'LIKELY FUTURE BLOCKER: staying on $currentVersion while $latest '
              'is published may eventually block transitive upgrades. '
              'This is an estimate based on metadata, not a guarantee.',
          likelyFutureBlocker: true,
          impact: 'moderate',
        ),
      );
    }

    if (meta?['sdkSupport'] != null) {
      recent.add('SDK support note: ${meta!['sdkSupport']}');
    }

    final release = ReleaseSignal(
      package: package,
      currentProjectVersion: currentVersion,
      latestVersion: latest,
      recentChanges: recent,
    );

    return {
      'package': package,
      'source': source,
      'stale': stale,
      'offline': offline,
      'release': release.toJson(),
      'events': [for (final e in events) e.toJson()],
      'compatibility': [for (final s in signals) s.toJson()],
      'deprecations': [for (final d in deprecations) d.toJson()],
      'projectImpact': signals.isEmpty ? 'low' : 'moderate',
    };
  }
}
