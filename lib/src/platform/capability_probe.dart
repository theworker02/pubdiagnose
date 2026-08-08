import 'dart:io';

import 'environment_adapter.dart';
import 'path_adapter.dart';
import 'platform_info.dart';

/// Probes optional host capabilities without requiring them.
abstract final class CapabilityProbe {
  /// Locate [executable] on PATH (returns absolute path or bare name).
  static String? which(
    String executable, {
    EnvironmentAdapter? environment,
    PlatformInfo? platform,
  }) {
    final env = environment ?? EnvironmentAdapter();
    final info = platform ?? PlatformInfo.detect(environment: env.all);
    final pathVar = env.path;
    if (pathVar == null || pathVar.isEmpty) return null;

    final paths = PathAdapter(info);
    final sep = info.isWindows ? ';' : ':';
    final extensions = info.isWindows
        ? <String>['', '.exe', '.bat', '.cmd', '.ps1']
        : <String>[''];

    for (final dir in pathVar.split(sep)) {
      if (dir.isEmpty) continue;
      for (final ext in extensions) {
        final candidate = paths.join(dir, '$executable$ext');
        try {
          if (File(candidate).existsSync()) return candidate;
        } on Object {
          continue;
        }
      }
    }
    return null;
  }

  /// Whether Flutter SDK appears available.
  static bool flutterAvailable({
    EnvironmentAdapter? environment,
    PlatformInfo? platform,
  }) {
    final env = environment ?? EnvironmentAdapter();
    if (env.has('FLUTTER_ROOT')) {
      final root = env['FLUTTER_ROOT']!;
      final paths = PathAdapter(platform ?? PlatformInfo.detect());
      final bin = paths.join(
        root,
        'bin',
        (platform ?? PlatformInfo.detect()).isWindows
            ? 'flutter.bat'
            : 'flutter',
      );
      if (File(bin).existsSync()) return true;
    }
    return which('flutter', environment: env, platform: platform) != null;
  }

  /// Whether Git appears available.
  static bool gitAvailable({
    EnvironmentAdapter? environment,
    PlatformInfo? platform,
  }) {
    return which('git', environment: environment, platform: platform) != null;
  }

  /// Whether the pub cache directory can be located.
  static String? locatePubCache({
    EnvironmentAdapter? environment,
    PlatformInfo? platform,
  }) {
    final env = environment ?? EnvironmentAdapter();
    final info = platform ?? PlatformInfo.detect(environment: env.all);
    final paths = PathAdapter(info);

    final explicit = env.pubCache;
    if (explicit != null && explicit.isNotEmpty) {
      if (Directory(explicit).existsSync()) return explicit;
    }

    final home = env.home;
    if (home == null) return null;

    if (info.isWindows) {
      final local = env['LOCALAPPDATA'];
      if (local != null) {
        final win = paths.join(local, 'Pub', 'Cache');
        if (Directory(win).existsSync()) return win;
      }
      final fallback = paths.join(home, 'AppData', 'Local', 'Pub', 'Cache');
      if (Directory(fallback).existsSync()) return fallback;
    }

    final posix = paths.join(home, '.pub-cache');
    if (Directory(posix).existsSync()) return posix;
    return null;
  }
}
