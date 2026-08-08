import '../analysis/import_scanner.dart';
import '../models/dependency_spec.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../workspace/workspace_loader.dart';

/// Known packages often used without direct Dart imports.
const Set<String> knownToolingPackages = {
  'build_runner',
  'build_web_compilers',
  'source_gen',
  'json_serializable',
  'freezed',
  'freezed_annotation',
  'hive_generator',
  'mockito',
  'mocktail',
  'test',
  'flutter_test',
  'flutter_lints',
  'lints',
  'very_good_analysis',
  'coverage',
  'dartdoc',
  'pana',
  'melos',
  'flutter_gen_runner',
  'injectable_generator',
  'auto_route_generator',
  'riverpod_generator',
  'go_router_builder',
};

/// Detects declared dependencies that appear unused based on imports.
class UnusedAnalyzer {
  /// Creates an unused-dependency analyzer.
  UnusedAnalyzer(this.workspace, {ImportScanner? scanner})
      : _scanner = scanner ?? ImportScanner(workspace.root);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  final ImportScanner _scanner;

  /// Findings with confidence.
  List<UnusedDependencyFinding> analyze() {
    final imports = _scanner.allImportedPackages();
    final rootName = workspace.pubspec.name;
    final findings = <UnusedDependencyFinding>[];

    void consider(DependencySpec spec) {
      if (spec.name == rootName) return;
      if (spec.source == DependencySource.sdk) return;
      if (imports.contains(spec.name)) return;

      final reasons = <String>[];
      var confidence = UnusedConfidence.high;

      if (knownToolingPackages.contains(spec.name)) {
        confidence = UnusedConfidence.medium;
        reasons.add(
          'No direct package:${spec.name}/ import found, but this is a '
          'common tooling/generator package that may be used via configuration '
          'or codegen.',
        );
      } else if (spec.name.endsWith('_generator') ||
          spec.name.endsWith('_builder') ||
          spec.name.contains('lints')) {
        confidence = UnusedConfidence.medium;
        reasons.add(
          'Name suggests a generator/linter package; may be used without '
          'Dart imports.',
        );
      } else {
        reasons.add(
          'No package:${spec.name}/ import or export found under '
          'lib/, bin/, test/, tool/, or example/.',
        );
      }

      reasons.add(
        spec.section == DependencySection.devDependency
            ? 'Declared in dev_dependencies.'
            : 'Declared in dependencies.',
      );

      if (spec.source == DependencySource.path ||
          spec.source == DependencySource.git) {
        if (confidence == UnusedConfidence.high) {
          confidence = UnusedConfidence.medium;
        }
        reasons
            .add('Non-hosted source (${spec.source.name}) — verify manually.');
      }

      findings.add(
        UnusedDependencyFinding(
          package: spec.name,
          section: spec.section == DependencySection.devDependency
              ? 'dev_dependencies'
              : 'dependencies',
          confidence: confidence,
          reasons: reasons,
        ),
      );
    }

    for (final spec in workspace.pubspec.dependencies) {
      consider(spec);
    }
    for (final spec in workspace.pubspec.devDependencies) {
      consider(spec);
    }

    findings.sort((a, b) {
      final c = b.confidence.index.compareTo(a.confidence.index);
      if (c != 0) return c;
      return a.package.compareTo(b.package);
    });
    return findings;
  }

  /// Diagnostics for medium+ confidence findings only.
  List<Diagnostic> toDiagnostics(List<UnusedDependencyFinding> findings) {
    return [
      for (final f in findings)
        if (f.confidence != UnusedConfidence.low)
          Diagnostic(
            code: DiagnosticCodes.unusedDependency,
            title: 'Possibly unused dependency',
            message: '"${f.package}" is declared in ${f.section} but no direct '
                'package import was found (${f.confidence.name} confidence).',
            severity: f.confidence == UnusedConfidence.high
                ? DiagnosticSeverity.warning
                : DiagnosticSeverity.info,
            package: f.package,
            evidence: f.reasons,
            remediation: 'Confirm the package is unused, then remove it from '
                '${f.section} and run `dart pub get`.',
          ),
    ];
  }
}
