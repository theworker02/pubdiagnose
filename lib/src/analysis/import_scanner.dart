import 'dart:io';

import 'package:path/path.dart' as p;

/// Scans Dart sources for `package:` imports/exports.
class ImportScanner {
  /// Creates a scanner rooted at [projectRoot].
  ImportScanner(this.projectRoot);

  /// Project root directory.
  final Directory projectRoot;

  static final _packageUri = RegExp(
    r"""(?:import|export)\s+['"]package:([a-zA-Z0-9_]+)\/[^'"]+['"]""",
  );

  /// Relative path → set of imported package names.
  Map<String, Set<String>> scan() {
    final result = <String, Set<String>>{};
    for (final dirName in const ['lib', 'bin', 'test', 'tool', 'example']) {
      final dir = Directory(p.join(projectRoot.path, dirName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        final base = p.basename(entity.path);
        if (base.endsWith('.g.dart') ||
            base.endsWith('.freezed.dart') ||
            base.endsWith('.mocks.dart')) {
          continue;
        }
        final rel = p.relative(entity.path, from: projectRoot.path);
        try {
          final content = entity.readAsStringSync();
          final packages = <String>{};
          for (final match in _packageUri.allMatches(content)) {
            packages.add(match.group(1)!);
          }
          if (packages.isNotEmpty) {
            result[rel] = packages;
          }
        } on Object {
          // Unreadable file — skip.
        }
      }
    }
    return result;
  }

  /// All imported package names across the project.
  Set<String> allImportedPackages() {
    final all = <String>{};
    for (final pkgs in scan().values) {
      all.addAll(pkgs);
    }
    return all;
  }
}

/// Whether [relativePath] is typically a dev/tool context.
bool isDevSourcePath(String relativePath) {
  final norm = relativePath.replaceAll('\\', '/');
  return norm.startsWith('test/') ||
      norm.startsWith('tool/') ||
      norm.contains('/test/') ||
      norm.contains('/tool/');
}
