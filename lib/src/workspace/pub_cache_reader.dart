import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../models/lockfile.dart';
import '../platform/capability_probe.dart';
import '../platform/environment_adapter.dart';
import '../platform/path_adapter.dart';
import '../platform/platform_info.dart';

/// Reads dependency maps for locked packages from the local pub cache.
class PubCacheReader {
  /// Creates a cache reader.
  PubCacheReader({String? cachePath})
      : cachePath = cachePath ?? _defaultCachePath();

  /// Pub cache root directory.
  final String cachePath;

  /// Resolves hosted package pubspec dependencies for [package] at [version].
  Map<String, String>? hostedDependencies({
    required String package,
    required Version version,
    String? hostedUrl,
  }) {
    final host = _hostedDirName(hostedUrl ?? 'https://pub.dev');
    final dir = Directory(
      p.join(cachePath, 'hosted', host, '$package-$version'),
    );
    final file = File(p.join(dir.path, 'pubspec.yaml'));
    if (!file.existsSync()) return null;
    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! YamlMap) return null;
      final deps = doc['dependencies'];
      if (deps is! YamlMap) return const {};
      final result = <String, String>{};
      for (final e in deps.entries) {
        if (e.key is! String) continue;
        result[e.key as String] = _constraintString(e.value);
      }
      return result;
    } on Object {
      return null;
    }
  }

  /// Enriches [lockfile] package dependency maps using the cache when missing.
  PubLockfile enrich(PubLockfile lockfile) {
    final packages = <String, LockedPackage>{};
    for (final entry in lockfile.packages.entries) {
      final pkg = entry.value;
      if (pkg.dependencies.isNotEmpty || pkg.source != 'hosted') {
        packages[entry.key] = pkg;
        continue;
      }
      final url = pkg.description['url']?.toString();
      final deps = hostedDependencies(
        package: pkg.name,
        version: pkg.version,
        hostedUrl: url,
      );
      if (deps == null) {
        packages[entry.key] = pkg;
      } else {
        packages[entry.key] = LockedPackage(
          name: pkg.name,
          version: pkg.version,
          dependency: pkg.dependency,
          source: pkg.source,
          description: pkg.description,
          sha256: pkg.sha256,
          dependencies: deps,
        );
      }
    }
    return PubLockfile(
      packages: packages,
      sdks: lockfile.sdks,
      lockfileVersion: lockfile.lockfileVersion,
    );
  }

  static String _constraintString(Object? value) {
    if (value == null) return 'any';
    if (value is String) return value;
    if (value is YamlMap && value.containsKey('version')) {
      return value['version']?.toString() ?? 'any';
    }
    if (value is YamlMap) return 'any';
    return value.toString();
  }

  static String _hostedDirName(String url) {
    // pub cache uses host like `pub.dev` or `pub.dartlang.org`.
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return url.replaceAll(RegExp(r'[^\w\.-]'), '_');
    }
    return uri.host;
  }

  static String _defaultCachePath() {
    final located = CapabilityProbe.locatePubCache();
    if (located != null) return located;
    // Fallbacks when the cache directory does not exist yet.
    final env = EnvironmentAdapter();
    final info = PlatformInfo.detect(environment: env.all);
    final paths = PathAdapter(info);
    final explicit = env.pubCache;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (info.isWindows) {
      final local = env['LOCALAPPDATA'];
      if (local != null) return paths.join(local, 'Pub', 'Cache');
      return paths.join(env['APPDATA'] ?? '', 'Pub', 'Cache');
    }
    return paths.join(env.home ?? '', '.pub-cache');
  }
}
