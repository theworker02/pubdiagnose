import 'capability_probe.dart';
import 'environment_adapter.dart';
import 'filesystem_adapter.dart';
import 'path_adapter.dart';
import 'platform_info.dart';
import 'process_adapter.dart';
import 'terminal_adapter.dart';

/// Aggregated portable platform services for PubDoctor.
class PlatformService {
  /// Creates a platform service from adapters.
  PlatformService({
    required this.info,
    required this.environment,
    required this.paths,
    required this.fs,
    required this.process,
    required this.terminal,
  });

  /// Detect and wire default adapters.
  factory PlatformService.detect({
    Map<String, String>? environment,
    bool allowProcess = true,
    bool? forceColor,
    bool? forceInteractive,
  }) {
    final env = EnvironmentAdapter(environment);
    final info = PlatformInfo.detect(environment: env.all);
    final paths = PathAdapter(info);
    final fs = FilesystemAdapter(paths);
    final process = ProcessAdapter(allowed: allowProcess);
    final terminal = TerminalAdapter(
      platform: info,
      environment: env,
      forceColor: forceColor,
      forceInteractive: forceInteractive,
    );
    return PlatformService(
      info: info,
      environment: env,
      paths: paths,
      fs: fs,
      process: process,
      terminal: terminal,
    );
  }

  /// Platform snapshot.
  final PlatformInfo info;

  /// Environment.
  final EnvironmentAdapter environment;

  /// Paths.
  final PathAdapter paths;

  /// Filesystem.
  final FilesystemAdapter fs;

  /// Processes.
  final ProcessAdapter process;

  /// Terminal.
  final TerminalAdapter terminal;

  /// Flutter availability (cached).
  late final bool flutterAvailable = CapabilityProbe.flutterAvailable(
    environment: environment,
    platform: info,
  );

  /// Git availability (cached).
  late final bool gitAvailable = CapabilityProbe.gitAvailable(
    environment: environment,
    platform: info,
  );

  /// Pub cache path if discoverable.
  late final String? pubCachePath = CapabilityProbe.locatePubCache(
    environment: environment,
    platform: info,
  );

  /// JSON summary for doctor-report.
  Map<String, Object?> toJson() => {
        'platform': info.toJson(),
        'shell': terminal.shell,
        'interactive': terminal.isInteractive,
        'ansi': terminal.supportsAnsi,
        'terminalWidth': terminal.width,
        'flutterAvailable': flutterAvailable,
        'gitAvailable': gitAvailable,
        'pubCachePresent': pubCachePath != null,
        'homePresent': environment.home != null,
      };
}
