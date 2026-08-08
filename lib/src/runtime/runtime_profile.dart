import '../platform/platform_service.dart';

/// Named runtime profile.
enum RuntimeProfileKind {
  /// Full desktop interactive.
  desktop,

  /// Alias-friendly full profile.
  full,

  /// Server / headless.
  server,

  /// Headless without interactive UI.
  headless,

  /// Container.
  container,

  /// Sandboxed / capability-limited.
  sandboxed,

  /// CI.
  ci,

  /// WSL.
  wsl,

  /// Restricted capabilities.
  restricted,

  /// Read-only filesystem.
  readOnly,

  /// Offline.
  offline,

  /// Remote workspace.
  remote,

  /// Embedded-like constrained device/runtime.
  embeddedLike,

  /// Ephemeral / disposable environment.
  ephemeral,
}

/// Detected runtime profile.
class RuntimeProfile {
  /// Creates a profile.
  const RuntimeProfile({
    required this.kind,
    required this.capabilities,
    this.notes = const [],
  });

  /// Kind.
  final RuntimeProfileKind kind;

  /// Capability map.
  final Map<String, Object?> capabilities;

  /// Notes.
  final List<String> notes;

  /// JSON.
  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'capabilities': capabilities,
        'notes': notes,
      };
}

/// Detects runtime environment.
class RuntimeDetector {
  /// Detect from [platform].
  static RuntimeProfile detect(
    PlatformService platform, {
    bool portable = false,
    bool offline = false,
    bool writable = true,
    bool minimal = false,
    bool remote = false,
    bool sandboxed = false,
    bool ephemeral = false,
  }) {
    final env = platform.environment;
    final ci = platform.info.isCi ||
        env['CI'] == 'true' ||
        env['GITHUB_ACTIONS'] == 'true' ||
        env['GITLAB_CI'] == 'true';
    final wsl = (env['WSL_DISTRO_NAME'] ?? '').isNotEmpty;
    final headless = !platform.terminal.isInteractive || ci;
    final kind = remote
        ? RuntimeProfileKind.remote
        : ephemeral
            ? RuntimeProfileKind.ephemeral
            : sandboxed
                ? RuntimeProfileKind.sandboxed
                : minimal
                    ? RuntimeProfileKind.embeddedLike
                    : !writable
                        ? RuntimeProfileKind.readOnly
                        : offline
                            ? RuntimeProfileKind.offline
                            : ci
                                ? RuntimeProfileKind.ci
                                : wsl
                                    ? RuntimeProfileKind.wsl
                                    : headless
                                        ? RuntimeProfileKind.headless
                                        : platform.info.isWindows ||
                                                platform.info.isMacOS ||
                                                platform.info.isLinux
                                            ? RuntimeProfileKind.full
                                            : RuntimeProfileKind.server;

    return RuntimeProfile(
      kind: kind,
      capabilities: {
        'os': platform.info.osName,
        'osFamily': platform.info.osFamily.name,
        'arch': platform.info.architectureHint,
        'flutterAvailable': platform.flutterAvailable,
        'gitAvailable': platform.gitAvailable,
        'ansi': platform.terminal.supportsAnsi,
        'interactive': platform.terminal.isInteractive,
        'portable': portable,
        'offline': offline,
        'writable': writable,
        'ci': ci,
        'wsl': wsl,
        'minimal': minimal,
        'remote': remote,
        'sandboxed': sandboxed,
        'ephemeral': ephemeral,
        'headless': headless,
      },
      notes: [
        if (portable) 'Portable mode: prefer project-local cache only.',
        if (offline) 'Offline: network enrichment disabled.',
        if (minimal) 'Minimal mode: expensive optional systems disabled.',
        if (remote) 'Remote workspace profile.',
        if (sandboxed) 'Sandboxed capability profile.',
        if (ephemeral) 'Ephemeral environment — avoid durable host state.',
      ],
    );
  }
}

/// Environment doctor report.
class EnvironmentReport {
  /// Creates a report.
  const EnvironmentReport({
    required this.profile,
    required this.capabilityLevel,
    this.unavailable = const [],
  });

  /// Profile.
  final RuntimeProfile profile;

  /// FULL / DEGRADED / RESTRICTED.
  final String capabilityLevel;

  /// Unavailable features.
  final List<String> unavailable;

  /// JSON.
  Map<String, Object?> toJson() => {
        'profile': profile.toJson(),
        'capabilityLevel': capabilityLevel,
        'unavailable': unavailable,
      };

  /// Build from platform.
  static EnvironmentReport fromPlatform(
    PlatformService platform, {
    bool portable = false,
    bool offline = false,
    bool writable = true,
    bool minimal = false,
    bool remote = false,
  }) {
    final profile = RuntimeDetector.detect(
      platform,
      portable: portable,
      offline: offline,
      writable: writable,
      minimal: minimal,
      remote: remote,
    );
    final unavailable = <String>[];
    if (!platform.flutterAvailable) {
      unavailable.add('Flutter SDK inspection');
    }
    if (offline) unavailable.add('Network metadata');
    if (!writable) unavailable.add('Filesystem writes');
    if (minimal) {
      unavailable.addAll([
        'Distributed workers',
        'Ecosystem live refresh',
        'Heavy source indexing',
      ]);
    }
    final level = !writable
        ? 'RESTRICTED'
        : minimal
            ? 'MINIMAL'
            : unavailable.length > 2
                ? 'DEGRADED'
                : 'FULL';
    return EnvironmentReport(
      profile: profile,
      capabilityLevel: level,
      unavailable: unavailable,
    );
  }
}
