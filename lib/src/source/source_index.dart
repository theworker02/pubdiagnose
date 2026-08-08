import 'dart:io';

import 'package:path/path.dart' as p;

import 'source_file.dart';

/// Indexes package/relative imports and part directives without a full parser.
class SourceIndex {
  /// Creates an index.
  SourceIndex(this.root);

  /// Project root.
  final Directory root;

  static final _packageUri = RegExp(
    r"""(?:import|export)\s+['"]package:([a-zA-Z0-9_]+)\/[^'"]+['"]""",
  );
  static final _relativeUri = RegExp(
    r"""(?:import|export)\s+['"](\.?\.?\/[^'"]+)['"]""",
  );
  static final _part = RegExp(r"""part\s+['"]([^'"]+)['"]\s*;""");
  static final _partOf = RegExp(r"""part\s+of\s+['"]([^'"]+)['"]\s*;""");

  /// Build index.
  List<SourceFile> build() {
    final files = <SourceFile>[];
    for (final dirName in const ['lib', 'bin', 'test', 'tool', 'example']) {
      final dir = Directory(p.join(root.path, dirName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = p.relative(entity.path, from: root.path);
        final base = p.basename(entity.path);
        final generated = base.endsWith('.g.dart') ||
            base.endsWith('.freezed.dart') ||
            base.endsWith('.mocks.dart');
        try {
          final content = entity.readAsStringSync();
          final packages = <String>{};
          for (final m in _packageUri.allMatches(content)) {
            packages.add(m.group(1)!);
          }
          final relatives = [
            for (final m in _relativeUri.allMatches(content)) m.group(1)!,
          ];
          final parts = [
            for (final m in _part.allMatches(content)) m.group(1)!,
          ];
          final partOfMatch = _partOf.firstMatch(content);
          files.add(
            SourceFile(
              path: rel.replaceAll('\\', '/'),
              packageImports: packages,
              relativeImports: relatives,
              parts: parts,
              partOf: partOfMatch?.group(1),
              isGenerated: generated,
            ),
          );
        } on Object {
          continue;
        }
      }
    }
    return files;
  }
}

/// Import-focused view of [SourceIndex].
class ImportIndex {
  /// Creates from files.
  ImportIndex(this.files);

  /// Files.
  final List<SourceFile> files;

  /// package → files importing it.
  Map<String, List<String>> byPackage() {
    final map = <String, List<String>>{};
    for (final f in files) {
      for (final pkg in f.packageImports) {
        map.putIfAbsent(pkg, () => []).add(f.path);
      }
    }
    return map;
  }
}

/// Minimal symbol index placeholder (declarations not fully parsed).
class SymbolIndex {
  /// Creates empty index.
  SymbolIndex(this.files);

  /// Files.
  final List<SourceFile> files;

  /// Count of indexed files.
  int get fileCount => files.length;
}

/// Workspace source view.
class SourceWorkspace {
  /// Creates a workspace.
  SourceWorkspace(this.root) : index = SourceIndex(root);

  /// Root directory.
  final Directory root;

  /// Index builder.
  final SourceIndex index;

  /// Cached files.
  List<SourceFile>? _files;

  /// Files (lazy).
  List<SourceFile> get files => _files ??= index.build();

  /// Import index.
  ImportIndex get imports => ImportIndex(files);

  /// Symbol index.
  SymbolIndex get symbols => SymbolIndex(files);

  /// Invalidate cache.
  void invalidate() => _files = null;
}
