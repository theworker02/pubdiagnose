import '../models/dependency_spec.dart';
import '../models/diagnostics.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';
import 'import_analyzer.dart';
import 'override_analyzer.dart';

/// Evidence-based dependency classification diagnostics.
class ClassificationAnalyzer {
  /// Creates a classification analyzer.
  ClassificationAnalyzer(this.workspace);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Collect classification diagnostics.
  List<Diagnostic> analyze() {
    return [
      ..._duplicates(),
      ..._devInDependencies(),
      ..._runtimeInDev(),
      ..._suspiciousOverrides(),
    ];
  }

  List<Diagnostic> _duplicates() {
    final result = <Diagnostic>[];
    final main = {for (final d in workspace.pubspec.dependencies) d.name};
    for (final d in workspace.pubspec.devDependencies) {
      if (!main.contains(d.name)) continue;
      result.add(
        Diagnostic(
          code: DiagnosticCodes.duplicateDependency,
          title: 'Duplicate dependency declaration',
          message: '"${d.name}" is declared in both dependencies and '
              'dev_dependencies.',
          severity: DiagnosticSeverity.error,
          package: d.name,
          evidence: ['listed in both dependency sections'],
          remediation: 'Keep a single declaration in the appropriate section.',
        ),
      );
    }
    return result;
  }

  List<Diagnostic> _devInDependencies() {
    const likelyDev = {
      'test',
      'flutter_test',
      'flutter_lints',
      'lints',
      'build_runner',
      'mockito',
      'mocktail',
      'coverage',
      'dartdoc',
      'very_good_analysis',
    };
    return [
      for (final d in workspace.pubspec.dependencies)
        if (likelyDev.contains(d.name))
          Diagnostic(
            code: DiagnosticCodes.misclassifiedDependency,
            title: 'Likely dev-only package in dependencies',
            message: '"${d.name}" is commonly development-only but is declared '
                'under dependencies.',
            severity: DiagnosticSeverity.info,
            package: d.name,
            evidence: ['heuristic classification based on package name'],
            remediation:
                'If not imported from lib/ or bin/, move to dev_dependencies.',
          ),
    ];
  }

  List<Diagnostic> _runtimeInDev() {
    final findings = ImportAnalyzer(workspace).analyze();
    final devNames = {
      for (final d in workspace.pubspec.devDependencies) d.name,
    };
    return [
      for (final f in findings)
        if (!f.isDevContext && devNames.contains(f.package))
          Diagnostic(
            code: DiagnosticCodes.misclassifiedDependency,
            title: 'Runtime import of dev_dependency',
            message: '"${f.package}" is in dev_dependencies but imported from '
                'production sources (lib/ or bin/).',
            severity: DiagnosticSeverity.warning,
            package: f.package,
            evidence: [for (final file in f.files.take(5)) 'import in $file'],
            remediation:
                'Move "${f.package}" to dependencies, or remove production imports.',
          ),
    ];
  }

  List<Diagnostic> _suspiciousOverrides() {
    final result = <Diagnostic>[];
    for (final a in OverrideAnalyzer(workspace).analyze()) {
      if (a.classification != OverrideClassification.unsafe) continue;
      result.add(
        Diagnostic(
          code: DiagnosticCodes.suspiciousOverride,
          title: 'Suspicious dependency override',
          message: a.explanation,
          severity: DiagnosticSeverity.warning,
          package: a.package,
          evidence: [
            if (a.declaredConstraint != null) a.declaredConstraint!,
            if (a.resolvedVersion != null) 'resolved ${a.resolvedVersion}',
          ],
          remediation: 'Review whether this override masks incompatibilities.',
        ),
      );
    }
    for (final spec in workspace.pubspec.dependencyOverrides) {
      if (spec.source != DependencySource.path &&
          spec.source != DependencySource.git) {
        continue;
      }
      if (workspace.pubspec.dependency(spec.name) != null) continue;
      result.add(
        Diagnostic(
          code: DiagnosticCodes.suspiciousOverride,
          title: 'Override without declared dependency',
          message: '"${spec.name}" is overridden (${spec.source.name}) but not '
              'declared in dependencies or dev_dependencies.',
          severity: DiagnosticSeverity.info,
          package: spec.name,
          evidence: [
            if (spec.path != null) 'path: ${spec.path}',
            if (spec.gitUrl != null) 'git: ${spec.gitUrl}',
          ],
          remediation: 'Ensure the override is intentional and documented.',
        ),
      );
    }
    return result;
  }
}
