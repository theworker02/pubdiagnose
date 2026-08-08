import 'package:path/path.dart' as p;

import 'platform_info.dart';

/// Portable path helpers (always use `package:path`, never hard-coded `/`).
class PathAdapter {
  /// Creates a path adapter for [platform].
  PathAdapter(this.platform)
      : context = platform.isWindows ? p.windows : p.posix;

  /// Host platform.
  final PlatformInfo platform;

  /// Active path context.
  final p.Context context;

  /// Join path segments.
  String join(
    String part1, [
    String? part2,
    String? part3,
    String? part4,
    String? part5,
    String? part6,
  ]) {
    final parts = <String>[
      part1,
      if (part2 != null) part2,
      if (part3 != null) part3,
      if (part4 != null) part4,
      if (part5 != null) part5,
      if (part6 != null) part6,
    ];
    return context.joinAll(parts);
  }

  /// Normalize.
  String normalize(String path) => context.normalize(path);

  /// Absolute path.
  String absolute(String path) => context.absolute(path);

  /// Basename.
  String basename(String path) => context.basename(path);

  /// Directory name.
  String dirname(String path) => context.dirname(path);

  /// Extension.
  String extension(String path) => context.extension(path);

  /// Relative path from [from] to [to].
  String relative(String path, {required String from}) =>
      context.relative(path, from: from);

  /// Whether [path] is absolute.
  bool isAbsolute(String path) => context.isAbsolute(path);

  /// Split into parts.
  List<String> split(String path) => context.split(path);
}
