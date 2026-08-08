import 'dart:io' as io show Platform;

/// Operating system family recognized by PubDoctor.
enum OsFamily {
  /// Microsoft Windows.
  windows,

  /// Apple macOS.
  macos,

  /// Linux distributions.
  linux,

  /// Other Unix-like (BSD, etc.) — treated gracefully.
  unix,

  /// Completely unknown / exotic.
  unknown,
}

/// Immutable snapshot of the host platform.
class PlatformInfo {
  /// Creates platform info.
  const PlatformInfo({
    required this.osFamily,
    required this.osName,
    required this.operatingSystemVersion,
    required this.numberOfProcessors,
    required this.localeName,
    required this.executable,
    required this.resolvedExecutable,
    required this.localHostname,
    required this.isCi,
    required this.architectureHint,
  });

  /// Detect from `dart:io` without failing on unfamiliar OS names.
  factory PlatformInfo.detect({Map<String, String>? environment}) {
    final env = environment ?? io.Platform.environment;
    final raw = io.Platform.operatingSystem.toLowerCase();
    final family = switch (raw) {
      'windows' => OsFamily.windows,
      'macos' => OsFamily.macos,
      'linux' => OsFamily.linux,
      'android' || 'fuchsia' || 'ios' => OsFamily.unix,
      _ when raw.contains('bsd') || raw.contains('unix') => OsFamily.unix,
      _ => OsFamily.unknown,
    };

    final ci = _detectCi(env);
    final arch = env['PROCESSOR_ARCHITECTURE'] ??
        env['CPU'] ??
        env['HOSTTYPE'] ??
        'unknown';

    return PlatformInfo(
      osFamily: family,
      osName: io.Platform.operatingSystem,
      operatingSystemVersion: io.Platform.operatingSystemVersion,
      numberOfProcessors: io.Platform.numberOfProcessors,
      localeName: io.Platform.localeName,
      executable: io.Platform.executable,
      resolvedExecutable: io.Platform.resolvedExecutable,
      localHostname: () {
        try {
          return io.Platform.localHostname;
        } on Object {
          return 'unknown';
        }
      }(),
      isCi: ci,
      architectureHint: arch,
    );
  }

  /// OS family bucket.
  final OsFamily osFamily;

  /// Raw OS name from the runtime.
  final String osName;

  /// OS version string.
  final String operatingSystemVersion;

  /// Logical CPU count.
  final int numberOfProcessors;

  /// Locale.
  final String localeName;

  /// Dart executable path.
  final String executable;

  /// Resolved Dart executable.
  final String resolvedExecutable;

  /// Hostname (best-effort).
  final String localHostname;

  /// Whether running under CI.
  final bool isCi;

  /// Best-effort architecture hint (may be unknown).
  final String architectureHint;

  /// Windows.
  bool get isWindows => osFamily == OsFamily.windows;

  /// macOS.
  bool get isMacOS => osFamily == OsFamily.macos;

  /// Linux.
  bool get isLinux => osFamily == OsFamily.linux;

  /// POSIX-like path / shell expectations.
  bool get isPosix =>
      osFamily == OsFamily.macos ||
      osFamily == OsFamily.linux ||
      osFamily == OsFamily.unix;

  /// JSON (sanitized — no secrets).
  Map<String, Object?> toJson() => {
        'osFamily': osFamily.name,
        'osName': osName,
        'operatingSystemVersion': operatingSystemVersion,
        'numberOfProcessors': numberOfProcessors,
        'localeName': localeName,
        'isCi': isCi,
        'architectureHint': architectureHint,
      };

  static bool _detectCi(Map<String, String> env) {
    const keys = [
      'CI',
      'CONTINUOUS_INTEGRATION',
      'GITHUB_ACTIONS',
      'GITLAB_CI',
      'CIRCLECI',
      'TF_BUILD',
      'BUILDKITE',
      'JENKINS_URL',
      'APPVEYOR',
      'TRAVIS',
    ];
    for (final k in keys) {
      final v = env[k];
      if (v != null && v.isNotEmpty && v.toLowerCase() != 'false') {
        return true;
      }
    }
    return false;
  }
}
