/// Sanitized Dart / Flutter SDK snapshot (no secrets).
class SdkSnapshot {
  /// Creates a snapshot.
  const SdkSnapshot({
    this.dartVersion,
    this.flutterVersion,
    this.dartChannel,
  });

  /// Dart version.
  final String? dartVersion;

  /// Flutter version if present.
  final String? flutterVersion;

  /// Channel hint.
  final String? dartChannel;

  /// JSON.
  Map<String, Object?> toJson() => {
        if (dartVersion != null) 'dartVersion': dartVersion,
        if (flutterVersion != null) 'flutterVersion': flutterVersion,
        if (dartChannel != null) 'dartChannel': dartChannel,
      };

  /// Parse.
  factory SdkSnapshot.fromJson(Map<String, Object?> json) => SdkSnapshot(
        dartVersion: json['dartVersion']?.toString(),
        flutterVersion: json['flutterVersion']?.toString(),
        dartChannel: json['dartChannel']?.toString(),
      );
}

/// Tool availability snapshot.
class ToolSnapshot {
  /// Creates a snapshot.
  const ToolSnapshot({
    this.gitAvailable = false,
    this.flutterAvailable = false,
    this.executables = const [],
  });

  /// Git.
  final bool gitAvailable;

  /// Flutter.
  final bool flutterAvailable;

  /// Safe executable names only (no paths with secrets).
  final List<String> executables;

  /// JSON.
  Map<String, Object?> toJson() => {
        'gitAvailable': gitAvailable,
        'flutterAvailable': flutterAvailable,
        'executables': executables,
      };

  /// Parse.
  factory ToolSnapshot.fromJson(Map<String, Object?> json) => ToolSnapshot(
        gitAvailable: json['gitAvailable'] == true,
        flutterAvailable: json['flutterAvailable'] == true,
        executables: [
          for (final e in (json['executables'] as List?) ?? const [])
            e.toString(),
        ],
      );
}

/// Pub cache location/state (sanitized).
class CacheSnapshot {
  /// Creates a snapshot.
  const CacheSnapshot({
    this.pubCachePresent = false,
    this.pubdoctorCachePresent = false,
    this.lockfilePackageCount = 0,
  });

  /// Whether a pub cache directory appears configured.
  final bool pubCachePresent;

  /// Whether project PubDoctor cache exists.
  final bool pubdoctorCachePresent;

  /// Lockfile package count.
  final int lockfilePackageCount;

  /// JSON.
  Map<String, Object?> toJson() => {
        'pubCachePresent': pubCachePresent,
        'pubdoctorCachePresent': pubdoctorCachePresent,
        'lockfilePackageCount': lockfilePackageCount,
      };

  /// Parse.
  factory CacheSnapshot.fromJson(Map<String, Object?> json) => CacheSnapshot(
        pubCachePresent: json['pubCachePresent'] == true,
        pubdoctorCachePresent: json['pubdoctorCachePresent'] == true,
        lockfilePackageCount:
            (json['lockfilePackageCount'] as num?)?.toInt() ?? 0,
      );
}

/// OS / arch / locale / path behavior.
class PlatformSnapshot {
  /// Creates a snapshot.
  const PlatformSnapshot({
    required this.os,
    required this.architecture,
    this.locale,
    this.pathSeparator = '/',
    this.isCi = false,
  });

  /// OS.
  final String os;

  /// Architecture.
  final String architecture;

  /// Locale (language tag only).
  final String? locale;

  /// Path separator.
  final String pathSeparator;

  /// CI.
  final bool isCi;

  /// JSON.
  Map<String, Object?> toJson() => {
        'os': os,
        'architecture': architecture,
        if (locale != null) 'locale': locale,
        'pathSeparator': pathSeparator,
        'isCi': isCi,
      };

  /// Parse.
  factory PlatformSnapshot.fromJson(Map<String, Object?> json) =>
      PlatformSnapshot(
        os: json['os']?.toString() ?? 'unknown',
        architecture: json['architecture']?.toString() ?? 'unknown',
        locale: json['locale']?.toString(),
        pathSeparator: json['pathSeparator']?.toString() ?? '/',
        isCi: json['isCi'] == true,
      );
}
