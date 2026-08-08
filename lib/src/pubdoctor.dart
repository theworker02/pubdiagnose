import 'analysis/package_explainer.dart';
import 'constraints/constraint_analyzer.dart';
import 'diagnostics/health_analyzer.dart';
import 'diagnostics/import_analyzer.dart';
import 'diagnostics/override_analyzer.dart';
import 'diagnostics/unused_analyzer.dart';
import 'kernel/pubdoctor_kernel.dart';
import 'kernel/pubdoctor_options.dart';
import 'metadata/package_repository.dart';
import 'models/constraints.dart';
import 'models/diagnostics.dart';
import 'models/health.dart';
import 'models/metadata.dart';
import 'models/recommendations.dart';
import 'recommendations/recommendation_engine.dart';
import 'recommendations/sdk_analyzer.dart';
import 'recommendations/upgrade_analyzer.dart';
import 'remediation/fix_plan.dart';
import 'remediation/fix_planner.dart';
import 'workspace/monorepo_analyzer.dart';
import 'workspace/workspace_loader.dart';

export 'kernel/operation_result.dart';
export 'kernel/pubdoctor_kernel.dart';
export 'kernel/pubdoctor_options.dart';

/// Facade for loading workspaces and running pubdoctor analyses.
///
/// Prefer [PubDoctor.open] for new code — it returns a [PubDoctorKernel] with
/// shared execution context, capabilities, and resilience services.
class PubDoctor {
  /// Creates a PubDoctor instance.
  PubDoctor({
    PackageRepository? repository,
    WorkspaceLoader? loader,
  })  : repository = repository ?? PubDevRepository(),
        _loader = loader ?? WorkspaceLoader();

  /// Package metadata repository (injectable).
  final PackageRepository repository;

  final WorkspaceLoader _loader;

  /// Open a workspace kernel (canonical programmatic entry).
  ///
  /// ```dart
  /// final doctor = await PubDoctor.open('.');
  /// final result = await doctor.check();
  /// await doctor.close();
  /// ```
  static Future<PubDoctorKernel> open(
    String directory, {
    PubDoctorOptions options = PubDoctorOptions.defaults,
    PackageRepository? repository,
  }) {
    return PubDoctorKernel.create(
      workspacePath: directory,
      options: repository == null
          ? options
          : options.copyWith(repository: repository),
    );
  }

  /// Loads a workspace from [directory] (default `.`).
  static Future<PubWorkspace> load(
    String directory, {
    WorkspaceLoader? loader,
  }) {
    return (loader ?? WorkspaceLoader()).load(directory);
  }

  /// Instance load using configured loader.
  Future<PubWorkspace> loadWorkspace(String directory) =>
      _loader.load(directory);

  /// Constraint conflicts for [workspace].
  List<DependencyConflict> analyzeConstraints(PubWorkspace workspace) {
    return ConstraintAnalyzer(workspace).analyze();
  }

  /// Constraint diagnostics for [workspace].
  List<Diagnostic> constraintDiagnostics(PubWorkspace workspace) {
    final analyzer = ConstraintAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }

  /// Override analyses for [workspace].
  List<OverrideAnalysis> analyzeOverrides(PubWorkspace workspace) {
    return OverrideAnalyzer(workspace).analyze();
  }

  /// Override diagnostics for [workspace].
  List<Diagnostic> overrideDiagnostics(PubWorkspace workspace) {
    final analyzer = OverrideAnalyzer(workspace);
    return analyzer.toDiagnostics(analyzer.analyze());
  }

  /// Unified health report (local analyses; pass [outdated] if precomputed).
  HealthReport check(
    PubWorkspace workspace, {
    List<OutdatedPackage> outdated = const [],
  }) {
    return HealthAnalyzer(workspace: workspace, outdated: outdated).analyze();
  }

  /// Health report with optional network outdated enrichment.
  Future<HealthReport> checkAsync(
    PubWorkspace workspace, {
    bool offline = false,
  }) async {
    if (offline) return check(workspace);
    return HealthAnalyzer.analyzeWithOutdated(
      workspace: workspace,
      upgradeAnalyzer: UpgradeAnalyzer(
        workspace: workspace,
        repository: repository,
      ),
    );
  }

  /// Unused dependency findings.
  List<UnusedDependencyFinding> unused(PubWorkspace workspace) =>
      UnusedAnalyzer(workspace).analyze();

  /// Undeclared import findings (PD1301).
  List<UndeclaredImportFinding> undeclaredImports(PubWorkspace workspace) =>
      ImportAnalyzer(workspace).analyze();

  /// Explain a package in project context.
  Future<PackageExplanation> explainPackage(
    PubWorkspace workspace,
    String package,
  ) {
    return PackageExplainer(
      workspace: workspace,
      repository: repository,
    ).explain(package);
  }

  /// Workspace / monorepo report.
  Future<WorkspaceReport> analyzeWorkspace(String directory) =>
      MonorepoAnalyzer().analyze(directory);

  /// Plan fixes without applying.
  FixPlan planFixes(
    PubWorkspace workspace, {
    String? code,
    String? package,
    bool safeOnly = false,
  }) {
    return FixPlanner(workspace).plan(
      code: code,
      package: package,
      safeOnly: safeOnly,
    );
  }

  /// Outdated packages with explanations.
  Future<List<OutdatedPackage>> outdated(
    PubWorkspace workspace, {
    bool directOnly = false,
  }) {
    return UpgradeAnalyzer(
      workspace: workspace,
      repository: repository,
    ).outdated(directOnly: directOnly);
  }

  /// Unlock analysis for [package].
  Future<UnlockReport> unlock(
    PubWorkspace workspace,
    String package, {
    String? version,
  }) {
    return UpgradeAnalyzer(
      workspace: workspace,
      repository: repository,
    ).unlock(package, version: version);
  }

  /// Dart SDK upgrade blockers.
  Future<SdkUpgradeReport> sdkDart(PubWorkspace workspace, String version) {
    return SdkAnalyzer(
      workspace: workspace,
      repository: repository,
    ).analyzeDart(version);
  }

  /// Flutter SDK upgrade blockers (Flutter install not required).
  Future<SdkUpgradeReport> sdkFlutter(PubWorkspace workspace, String version) {
    return SdkAnalyzer(
      workspace: workspace,
      repository: repository,
    ).analyzeFlutter(version);
  }

  /// Recommendations from overrides + outdated (when provided).
  List<Recommendation> recommendations({
    required PubWorkspace workspace,
    List<OverrideAnalysis>? overrides,
    List<OutdatedPackage>? outdated,
  }) {
    final engine = RecommendationEngine(workspace);
    return [
      if (overrides != null) ...engine.fromOverrides(overrides),
      if (outdated != null) ...engine.fromOutdated(outdated),
    ];
  }
}

/// Extension methods on [PubWorkspace] for ergonomic analysis.
extension PubWorkspaceAnalysis on PubWorkspace {
  /// Analyze constraints.
  List<DependencyConflict> analyzeConstraints() =>
      ConstraintAnalyzer(this).analyze();

  /// Analyze overrides.
  List<OverrideAnalysis> analyzeOverrides() => OverrideAnalyzer(this).analyze();

  /// Plan remediations without applying.
  FixPlan planFixes({String? code, String? package, bool safeOnly = false}) =>
      FixPlanner(this).plan(code: code, package: package, safeOnly: safeOnly);

  /// Local health check.
  HealthReport check() => HealthAnalyzer(workspace: this).analyze();
}
