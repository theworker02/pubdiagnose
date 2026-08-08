import '../constraints/constraint_analyzer.dart';
import '../diagnostics/classification_analyzer.dart';
import '../diagnostics/import_analyzer.dart';
import '../diagnostics/override_analyzer.dart';
import '../diagnostics/unused_analyzer.dart';
import '../kernel/capability_registry.dart';
import '../kernel/execution_context.dart';
import '../models/diagnostics.dart';
import '../recommendations/upgrade_analyzer.dart';
import '../resilience/analyzer_pipeline.dart';
import '../workspace/workspace_loader.dart';

/// Built-in analyzer modules used by the kernel pipeline.
abstract final class BuiltinModules {
  /// Local-only modules (no network).
  static List<AnalyzerModule> local() => [
        _ConstraintsModule(),
        _OverridesModule(),
        _ClassificationModule(),
        _ImportsModule(),
        _UnusedModule(),
      ];

  /// Optional network outdated module.
  static AnalyzerModule outdated() => _OutdatedModule();
}

class _ConstraintsModule extends AnalyzerModule {
  @override
  String get id => 'constraints';

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final analyzer = ConstraintAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }
}

class _OverridesModule extends AnalyzerModule {
  @override
  String get id => 'overrides';

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final analyzer = OverrideAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }
}

class _ClassificationModule extends AnalyzerModule {
  @override
  String get id => 'classification';

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    return ClassificationAnalyzer(workspace).analyze();
  }
}

class _ImportsModule extends AnalyzerModule {
  @override
  String get id => 'imports';

  @override
  List<PubDoctorCapability> get requiredCapabilities =>
      const [PubDoctorCapability.filesystemRead];

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final analyzer = ImportAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }
}

class _UnusedModule extends AnalyzerModule {
  @override
  String get id => 'unused';

  @override
  List<String> get dependsOn => const ['imports'];

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final analyzer = UnusedAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }
}

class _OutdatedModule extends AnalyzerModule {
  @override
  String get id => 'outdated';

  @override
  List<PubDoctorCapability> get requiredCapabilities =>
      const [PubDoctorCapability.networkHttp];

  @override
  ModuleFailureSeverity get onFailure => ModuleFailureSeverity.info;

  @override
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final outdated = await UpgradeAnalyzer(
      workspace: workspace,
      repository: context.repository,
    ).outdated(directOnly: true);

    final diagnostics = <Diagnostic>[];
    for (final o in outdated) {
      if (o.blockers.isEmpty || !o.hasIncompatibleNewer) continue;
      diagnostics.add(
        Diagnostic(
          code: DiagnosticCodes.upgradeBlocked,
          title: 'Upgrade blocked',
          message: o.explanation ??
              '${o.package} cannot reach ${o.latestStable} under current '
                  'constraints.',
          severity: DiagnosticSeverity.info,
          package: o.package,
          evidence: [for (final b in o.blockers.take(4)) b.explanation],
          remediation: 'Inspect with `pubdoctor unlock ${o.package}`.',
        ),
      );
    }
    return diagnostics;
  }
}
