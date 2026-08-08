import 'dart:io';

import 'package:path/path.dart' as p;

import '../workspace/workspace_loader.dart';
import 'source_file.dart';
import 'source_index.dart';

export 'source_file.dart';
export 'source_index.dart';

/// Project-level source diagnostics (not a full Dart analyzer replacement).
class SourceChecker {
  /// Creates a checker.
  SourceChecker(this.workspace);

  /// Workspace.
  final PubWorkspace workspace;

  /// Run source check.
  List<SourceDiagnostic> check() {
    final sw = SourceWorkspace(workspace.root);
    final files = sw.files;
    final filePaths = {for (final f in files) f.path};
    final direct = {
      for (final d in workspace.pubspec.allDependencies) d.name,
    };
    final lock = workspace.lockfile?.packages.keys.toSet() ?? {};
    final diagnostics = <SourceDiagnostic>[];

    for (final f in files) {
      if (f.isGenerated) continue;
      for (final pkg in f.packageImports) {
        if (pkg == workspace.pubspec.name) continue;
        if (!direct.contains(pkg) && lock.contains(pkg)) {
          diagnostics.add(
            SourceDiagnostic(
              code: 'PDS101',
              message:
                  'Imports package:$pkg which is only available transitively.',
              location: SourceLocation(path: f.path),
              package: pkg,
              evidence: ['import in ${f.path}'],
              repairHint: 'Add "$pkg" to dependencies.',
            ),
          );
        } else if (!direct.contains(pkg) && !lock.contains(pkg)) {
          diagnostics.add(
            SourceDiagnostic(
              code: 'PDS102',
              message: 'Imports undeclared package:$pkg.',
              location: SourceLocation(path: f.path),
              package: pkg,
              evidence: ['import in ${f.path}'],
              repairHint: 'Add "$pkg" to dependencies or remove the import.',
            ),
          );
        }
      }

      for (final rel in f.relativeImports) {
        final target = _resolveRelative(f.path, rel);
        if (target == null) continue;
        final abs = p.join(workspace.root.path, target);
        if (!filePaths.contains(target) && !File(abs).existsSync()) {
          diagnostics.add(
            SourceDiagnostic(
              code: 'PDS110',
              message: 'Broken relative import "$rel".',
              location: SourceLocation(path: f.path),
              evidence: ['resolved: $target'],
              repairHint: 'Fix or remove the import.',
            ),
          );
        }
      }

      for (final partUri in f.parts) {
        final target = _resolveRelative(f.path, partUri);
        if (target == null) continue;
        final abs = p.join(workspace.root.path, target);
        if (!File(abs).existsSync()) {
          diagnostics.add(
            SourceDiagnostic(
              code: 'PDS120',
              message: 'Invalid part directive "$partUri".',
              location: SourceLocation(path: f.path),
              evidence: ['missing: $target'],
              repairHint: 'Repair or remove the part directive.',
            ),
          );
        }
      }
    }

    return diagnostics;
  }

  String? _resolveRelative(String from, String uri) {
    try {
      final dir = p.dirname(from);
      return p.normalize(p.join(dir, uri)).replaceAll('\\', '/');
    } on Object {
      return null;
    }
  }
}
