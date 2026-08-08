import 'package:pub_semver/pub_semver.dart';

import '../version.dart';

/// Dart SDK compatibility helpers.
abstract final class DartCompatibility {
  /// Parse a Dart SDK constraint string safely.
  static VersionConstraint? tryParseConstraint(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return VersionConstraint.parse(raw);
    } on Object {
      return null;
    }
  }

  /// Whether [sdkVersion] satisfies [constraint].
  static bool allows(VersionConstraint? constraint, String sdkVersion) {
    if (constraint == null) return true;
    try {
      final v = Version.parse(_normalize(sdkVersion));
      return constraint.allows(v);
    } on Object {
      return true;
    }
  }

  static String _normalize(String version) {
    final cleaned = version.trim();
    if (RegExp(r'^\d+\.\d+$').hasMatch(cleaned)) return '$cleaned.0';
    return cleaned;
  }
}

/// Flutter compatibility helpers (no Flutter install required).
abstract final class FlutterCompatibility {
  /// Best-effort map of Flutter version → bundled Dart (partial matrix).
  static const Map<String, String> knownDartSdks = {
    '3.16.0': '3.2.0',
    '3.19.0': '3.3.0',
    '3.22.0': '3.4.0',
    '3.24.0': '3.5.0',
    '3.27.0': '3.6.0',
    '3.29.0': '3.7.0',
  };

  /// Look up bundled Dart for a Flutter version (null if unknown — tolerated).
  static String? dartForFlutter(String flutterVersion) {
    final exact = knownDartSdks[flutterVersion];
    if (exact != null) return exact;
    // Prefix match major.minor
    final parts = flutterVersion.split('.');
    if (parts.length >= 2) {
      final prefix = '${parts[0]}.${parts[1]}';
      for (final e in knownDartSdks.entries) {
        if (e.key.startsWith(prefix)) return e.value;
      }
    }
    return null;
  }
}

/// Pub / pubspec format compatibility.
abstract final class PubCompatibility {
  /// Keys that are safe to preserve on edit even if unknown to PubDoctor.
  static const preservedUnknownKeys = true;

  /// Lockfile format generations we parse.
  static const supportedLockfileVersions = [1, 2, 3];

  /// Whether an unknown pubspec key should be preserved.
  static bool shouldPreserveKey(String key) {
    // Always preserve — never silently discard user config.
    return true;
  }
}

/// Schema migration engine — upgrades persisted formats without discarding data.
class SchemaMigrationEngine {
  /// Migrate a JSON map from [fromVersion] toward [toVersion].
  Map<String, Object?> migrate({
    required Map<String, Object?> data,
    required int fromVersion,
    required int toVersion,
    required String format,
  }) {
    var current = Map<String, Object?>.from(data);
    var version = fromVersion;
    while (version < toVersion) {
      current = _step(format, version, current);
      version++;
      current['schemaVersion'] = version;
    }
    return current;
  }

  Map<String, Object?> _step(
    String format,
    int from,
    Map<String, Object?> data,
  ) {
    // v1 is current for all formats — identity migration preserves keys.
    return Map<String, Object?>.from(data);
  }
}

/// High-level compatibility matrix for docs / `pubdoctor version`.
abstract final class CompatibilityMatrix {
  /// Human-readable support statement.
  static Map<String, Object?> snapshot() => {
        'pubdoctor': pubdoctorPackageVersion,
        'dartSdk': '>=3.5.0 <4.0.0',
        'platforms': ['windows', 'macos', 'linux', 'unix-unknown'],
        'architectures': ['x64', 'arm64'],
        'requires': {
          'docker': false,
          'flutter': false,
          'git': false,
          'bash': false,
          'powershell': false,
          'node': false,
          'python': false,
          'nativeBinaries': false,
        },
        'lockfileVersions': PubCompatibility.supportedLockfileVersions,
        'flutterDartHints': FlutterCompatibility.knownDartSdks.length,
      };
}
