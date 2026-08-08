import '../constraints/constraint_analyzer.dart';
import '../diagnostics/classification_analyzer.dart';
import '../diagnostics/import_analyzer.dart';
import '../diagnostics/override_analyzer.dart';
import '../diagnostics/unused_analyzer.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../models/metadata.dart';
import '../recommendations/upgrade_analyzer.dart';
import '../workspace/workspace_loader.dart';

/// Builds a unified [HealthReport] for `pubdoctor check`.
class HealthAnalyzer {
  /// Creates a health analyzer.
  HealthAnalyzer({
    required this.workspace,
    this.outdated = const [],
    this.includeImportAnalysis = true,
    this.includeUnused = true,
  });

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Optional outdated results (from network).
  final List<OutdatedPackage> outdated;

  /// Whether to scan imports.
  final bool includeImportAnalysis;

  /// Whether to analyze unused deps.
  final bool includeUnused;

  /// Runs local analyses and builds a report.
  HealthReport analyze() {
    final pubspec = workspace.pubspec;
    final lockfile = workspace.lockfile;

    final direct = pubspec.dependencies.length;
    final dev = pubspec.devDependencies.length;
    final overrides = pubspec.dependencyOverrides.length;
    final transitive = lockfile == null
        ? 0
        : lockfile.packages.values.where((p) => p.isTransitive).length;

    final constraintAnalyzer = ConstraintAnalyzer(workspace);
    final conflicts = constraintAnalyzer.analyze();
    final hardConflicts = conflicts.where((c) => c.intersection.isEmpty).length;

    final diagnostics = <Diagnostic>[
      ...constraintAnalyzer.toDiagnostics(conflicts),
      ...OverrideAnalyzer(workspace).toDiagnostics(
        OverrideAnalyzer(workspace).analyze(),
      ),
      ...ClassificationAnalyzer(workspace).analyze(),
    ];

    if (includeImportAnalysis) {
      final imports = ImportAnalyzer(workspace);
      diagnostics.addAll(imports.toDiagnostics(imports.analyze()));
    }
    if (includeUnused) {
      final unused = UnusedAnalyzer(workspace);
      diagnostics.addAll(unused.toDiagnostics(unused.analyze()));
    }

    if (lockfile == null) {
      diagnostics.add(
        const Diagnostic(
          code: 'PD0005',
          title: 'Missing lockfile',
          message:
              'pubspec.lock was not found. Run `dart pub get` for complete '
              'graph, outdated, and override analysis.',
          severity: DiagnosticSeverity.warning,
          remediation: 'Run `dart pub get` in the project directory.',
        ),
      );
    }

    final constrainedUpgrades =
        outdated.where((o) => o.hasCompatibleUpgrade).length;

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

    diagnostics.sort((a, b) {
      final s = b.severity.index.compareTo(a.severity.index);
      if (s != 0) return s;
      return a.code.compareTo(b.code);
    });

    final status = _status(diagnostics, hardConflicts);
    return HealthReport(
      projectName: pubspec.name,
      status: status,
      directDependencyCount: direct,
      devDependencyCount: dev,
      transitiveDependencyCount: transitive,
      overrideCount: overrides,
      outdatedCount: outdated.length,
      constrainedUpgradeCount: constrainedUpgrades,
      conflictCount: hardConflicts,
      hasLockfile: lockfile != null,
      summary: _summary(status, hardConflicts, diagnostics.length,
          outdated.length, overrides),
      diagnostics: diagnostics,
      outdated: outdated,
    );
  }

  /// Fetch outdated then analyze (network; degrades offline).
  static Future<HealthReport> analyzeWithOutdated({
    required PubWorkspace workspace,
    required UpgradeAnalyzer upgradeAnalyzer,
    bool directOnly = true,
    bool includeImportAnalysis = true,
    bool includeUnused = true,
  }) async {
    var outdated = const <OutdatedPackage>[];
    try {
      outdated = await upgradeAnalyzer.outdated(directOnly: directOnly);
    } on Object {
      // Offline / missing lockfile — local-only report.
    }
    return HealthAnalyzer(
      workspace: workspace,
      outdated: outdated,
      includeImportAnalysis: includeImportAnalysis,
      includeUnused: includeUnused,
    ).analyze();
  }

  HealthStatus _status(List<Diagnostic> diagnostics, int hardConflicts) {
    if (hardConflicts > 0 ||
        diagnostics.any(
          (d) =>
              d.severity == DiagnosticSeverity.error ||
              d.severity == DiagnosticSeverity.critical,
        )) {
      return HealthStatus.unhealthy;
    }
    if (diagnostics.isNotEmpty) return HealthStatus.attentionRequired;
    return HealthStatus.healthy;
  }

  String _summary(
    HealthStatus status,
    int conflicts,
    int diagnostics,
    int outdated,
    int overrides,
  ) {
    switch (status) {
      case HealthStatus.healthy:
        return 'HEALTHY — no dependency diagnostics.';
      case HealthStatus.attentionRequired:
        return 'ATTENTION REQUIRED — $diagnostics finding(s)'
            '${outdated > 0 ? ', $outdated outdated' : ''}'
            '${overrides > 0 ? ', $overrides override(s)' : ''}.';
      case HealthStatus.unhealthy:
        return 'UNHEALTHY — $conflicts conflict(s), $diagnostics finding(s).';
    }
  }
}
