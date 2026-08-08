import 'dart:io' show Platform;

import '../kernel/capability_registry.dart';
import '../platform/platform_service.dart';
import '../workspace/workspace_loader.dart';
import 'sdk_snapshot.dart';

export 'sdk_snapshot.dart';

/// Full sanitized environment snapshot for reproducibility.
class EnvironmentSnapshot {
  /// Creates a snapshot.
  const EnvironmentSnapshot({
    required this.capturedAt,
    required this.sdk,
    required this.tools,
    required this.cache,
    required this.platform,
    required this.capabilities,
    this.projectName,
    this.lockfileHash,
    this.schemaVersion = 1,
  });

  /// Capture time UTC.
  final DateTime capturedAt;

  /// SDK.
  final SdkSnapshot sdk;

  /// Tools.
  final ToolSnapshot tools;

  /// Cache.
  final CacheSnapshot cache;

  /// Platform.
  final PlatformSnapshot platform;

  /// PubDoctor capability ids.
  final List<String> capabilities;

  /// Project name if known.
  final String? projectName;

  /// Stable hash of lockfile content (not the secret-bearing path).
  final String? lockfileHash;

  /// Schema version.
  final int schemaVersion;

  /// JSON (never includes secrets / tokens / home paths).
  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'sdk': sdk.toJson(),
        'tools': tools.toJson(),
        'cache': cache.toJson(),
        'platform': platform.toJson(),
        'capabilities': capabilities,
        if (projectName != null) 'projectName': projectName,
        if (lockfileHash != null) 'lockfileHash': lockfileHash,
      };

  /// Parse.
  factory EnvironmentSnapshot.fromJson(Map<String, Object?> json) {
    return EnvironmentSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      capturedAt: DateTime.parse(json['capturedAt']! as String),
      sdk: SdkSnapshot.fromJson(
        Map<String, Object?>.from(
          (json['sdk'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      tools: ToolSnapshot.fromJson(
        Map<String, Object?>.from(
          (json['tools'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      cache: CacheSnapshot.fromJson(
        Map<String, Object?>.from(
          (json['cache'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      platform: PlatformSnapshot.fromJson(
        Map<String, Object?>.from(
          (json['platform'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      capabilities: [
        for (final c in (json['capabilities'] as List?) ?? const [])
          c.toString(),
      ],
      projectName: json['projectName']?.toString(),
      lockfileHash: json['lockfileHash']?.toString(),
    );
  }
}

/// Builds [EnvironmentSnapshot] from platform + workspace.
class EnvironmentSnapshotEngine {
  /// Capture a sanitized snapshot.
  static EnvironmentSnapshot capture({
    required PlatformService platform,
    CapabilityRegistry? capabilities,
    PubWorkspace? workspace,
    bool pubdoctorCachePresent = false,
  }) {
    final env = platform.environment;
    // Never copy secret-like env keys.
    final locale = env['LANG'] ?? env['LC_ALL'] ?? platform.info.localeName;
    final dartVer = Platform.version.split(' ').first;
    final lockHash = workspace?.lockfile == null
        ? null
        : _stableHash(
            [
              for (final e in workspace!.lockfile!.packages.entries)
                '${e.key}@${e.value.version}',
            ]..sort(),
          );

    return EnvironmentSnapshot(
      capturedAt: DateTime.now().toUtc(),
      sdk: SdkSnapshot(
        dartVersion: dartVer,
        flutterVersion: platform.flutterAvailable ? 'available' : null,
      ),
      tools: ToolSnapshot(
        gitAvailable: platform.gitAvailable,
        flutterAvailable: platform.flutterAvailable,
        executables: [
          'dart',
          if (platform.flutterAvailable) 'flutter',
          if (platform.gitAvailable) 'git',
        ],
      ),
      cache: CacheSnapshot(
        pubCachePresent: (env['PUB_CACHE'] ?? '').isNotEmpty ||
            platform.info.isWindows ||
            platform.info.isLinux ||
            platform.info.isMacOS,
        pubdoctorCachePresent: pubdoctorCachePresent,
        lockfilePackageCount: workspace?.lockfile?.packages.length ?? 0,
      ),
      platform: PlatformSnapshot(
        os: platform.info.osName,
        architecture: platform.info.architectureHint,
        locale: locale.split('.').first,
        pathSeparator: platform.info.isWindows ? r'\' : '/',
        isCi: platform.info.isCi,
      ),
      capabilities: capabilities?.toJson() ?? const [],
      projectName: workspace?.pubspec.name,
      lockfileHash: lockHash,
    );
  }

  static String _stableHash(List<String> parts) {
    // Simple FNV-1a 32-bit — not cryptographic; fingerprint only.
    var hash = 0x811c9dc5;
    final joined = parts.join('|');
    for (final code in joined.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Strip any accidental secret-like keys from a raw map before export.
  static Map<String, Object?> sanitize(Map<String, Object?> raw) {
    final blocked = RegExp(
      r'(token|secret|password|key|credential|authorization)',
      caseSensitive: false,
    );
    final out = <String, Object?>{};
    for (final e in raw.entries) {
      if (blocked.hasMatch(e.key)) continue;
      final v = e.value;
      if (v is Map) {
        out[e.key] =
            sanitize(Map<String, Object?>.from(v.cast<String, Object?>()));
      } else if (v is String && blocked.hasMatch(v)) {
        continue;
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }
}
