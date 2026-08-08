import '../analysis/import_scanner.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../workspace/workspace_loader.dart';

/// Detects direct imports of packages not declared in the appropriate section.
class ImportAnalyzer {
  /// Creates an import analyzer.
  ImportAnalyzer(this.workspace, {ImportScanner? scanner})
      : _scanner = scanner ?? ImportScanner(workspace.root);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  final ImportScanner _scanner;

  /// Findings for PD1301.
  List<UndeclaredImportFinding> analyze() {
    final byFile = _scanner.scan();
    final rootName = workspace.pubspec.name;
    final declaredMain = {
      for (final d in workspace.pubspec.dependencies) d.name,
    };
    final declaredDev = {
      for (final d in workspace.pubspec.devDependencies) d.name,
    };
    final declaredAny = {...declaredMain, ...declaredDev, rootName};
    final map = <String, _Agg>{};

    for (final entry in byFile.entries) {
      final file = entry.key;
      final dev = isDevSourcePath(file);
      for (final package in entry.value) {
        if (package == rootName) continue;
        if (declaredAny.contains(package)) {
          if (!dev &&
              declaredDev.contains(package) &&
              !declaredMain.contains(package)) {
            final agg = map.putIfAbsent(package, _Agg.new);
            agg.files.add(file);
            agg.seenInProd = true;
            agg.declaredDevOnly = true;
          }
          continue;
        }
        final agg = map.putIfAbsent(package, _Agg.new);
        agg.files.add(file);
        if (dev) {
          agg.seenInDev = true;
        } else {
          agg.seenInProd = true;
        }
      }
    }

    final lockfile = workspace.lockfile;
    final findings = <UndeclaredImportFinding>[];
    for (final entry in map.entries) {
      final package = entry.key;
      final agg = entry.value;
      final locked = lockfile?[package];
      final transitiveOnly = locked == null || locked.isTransitive;
      findings.add(
        UndeclaredImportFinding(
          package: package,
          files: agg.files.toList()..sort(),
          isDevContext: agg.seenInDev && !agg.seenInProd,
          transitiveOnly: transitiveOnly || agg.declaredDevOnly,
        ),
      );
    }
    findings.sort((a, b) => a.package.compareTo(b.package));
    return findings;
  }

  /// PD1301 diagnostics.
  List<Diagnostic> toDiagnostics(List<UndeclaredImportFinding> findings) {
    return [
      for (final f in findings)
        Diagnostic(
          code: DiagnosticCodes.directImportNotDeclared,
          title: 'Direct import not declared',
          message: f.isDevContext
              ? 'Package "${f.package}" is imported from test/tool sources '
                  'but is not declared in dev_dependencies'
                  '${f.transitiveOnly ? ' (transitive-only today)' : ''}.'
              : 'Package "${f.package}" is imported directly but is not '
                  'declared in dependencies'
                  '${f.transitiveOnly ? ' (currently transitive-only)' : ''}.',
          severity: DiagnosticSeverity.warning,
          package: f.package,
          evidence: [
            for (final file in f.files.take(8)) 'import in $file',
            if (f.files.length > 8) '…and ${f.files.length - 8} more file(s)',
          ],
          remediation: f.isDevContext
              ? 'Add "${f.package}" to dev_dependencies, then run `dart pub get`.'
              : 'Add "${f.package}" to dependencies (do not rely on transitive '
                  'deps), then run `dart pub get`.',
        ),
    ];
  }
}

class _Agg {
  final files = <String>{};
  bool seenInDev = false;
  bool seenInProd = false;
  bool declaredDevOnly = false;
}
