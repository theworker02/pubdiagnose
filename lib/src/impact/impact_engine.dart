import '../analysis/import_scanner.dart';
import '../models/diagnostics.dart';
import '../workspace/workspace_loader.dart';
import 'impact_report.dart';

/// Reverse-dependency change impact analysis.
class ImpactEngine {
  /// Creates an impact engine.
  ImpactEngine(this.workspace, {this.pathLimit = 16});

  /// Workspace.
  final PubWorkspace workspace;

  /// Max paths to expand per package.
  final int pathLimit;

  /// Impact of upgrading [package] to [version].
  ImpactReport upgradePackage(String package, String version) {
    final simulation = ChangeSimulation(
      kind: ChangeSimulationKind.upgradePackage,
      package: package,
      version: version,
    );
    final graph = workspace.graph;
    final parents = graph.parentsOf(package);
    final paths = graph.pathsTo(package, limit: pathLimit);
    final affected = <AffectedPackage>[
      AffectedPackage(
        name: package,
        reason: 'Target of upgrade to $version',
        isDirect: workspace.pubspec.dependency(package) != null,
        evidence: [
          if (workspace.lockfile?[package] != null)
            'locked: ${workspace.lockfile![package]!.version}',
          'target: $version',
        ],
      ),
      for (final parent in parents)
        if (parent != graph.rootName)
          AffectedPackage(
            name: parent,
            reason: 'Depends on $package (may need constraint change)',
            isDirect: workspace.pubspec.dependency(parent) != null,
            evidence: ['parentOf: $package'],
          ),
    ];

    final diagnostics = <Diagnostic>[
      if (parents.length > 3)
        Diagnostic(
          code: DiagnosticCodes.impactWarning,
          title: 'Wide upgrade impact',
          message:
              'Upgrading "$package" may affect ${parents.length} parent packages.',
          severity: DiagnosticSeverity.warning,
          package: package,
          evidence: [for (final p in parents.take(10)) 'parent: $p'],
        ),
    ];

    return ImpactReport(
      simulation: simulation,
      affectedPackages: affected,
      affectedPaths: [
        for (final p in paths)
          AffectedPath(path: p, reason: 'Path through $package'),
      ],
      safeToApply:
          parents.length <= 1 && workspace.pubspec.dependency(package) != null,
      summary:
          'Upgrade of $package → $version touches ${affected.length} packages '
          'across ${paths.length} sampled path(s).',
      diagnostics: diagnostics,
    );
  }

  /// Impact of removing [package].
  ImpactReport removePackage(String package) {
    final simulation = ChangeSimulation(
      kind: ChangeSimulationKind.removePackage,
      package: package,
    );
    final graph = workspace.graph;
    final parents = graph.parentsOf(package);
    final descendants = graph.descendants(package).map((n) => n.name).toList();
    final paths = graph.pathsTo(package, limit: pathLimit);

    final importedFiles = <String>[];
    try {
      final scanned = ImportScanner(workspace.root).scan();
      for (final e in scanned.entries) {
        if (e.value.contains(package)) importedFiles.add(e.key);
      }
    } on Object {
      // best-effort
    }

    final isDirect = workspace.pubspec.dependency(package) != null;
    final inLock = workspace.lockfile?[package] != null;
    final transitiveUsers = parents.where((p) => p != graph.rootName).toList();

    final affected = <AffectedPackage>[
      AffectedPackage(
        name: package,
        reason: 'Removal target',
        isDirect: isDirect,
        importsPackage: importedFiles.isNotEmpty,
        evidence: [
          if (isDirect) 'declared in pubspec',
          if (inLock) 'present in lockfile',
          if (importedFiles.isNotEmpty)
            'imported in ${importedFiles.length} file(s)',
        ],
      ),
      for (final p in transitiveUsers)
        AffectedPackage(
          name: p,
          reason: 'May lose transitive access to $package',
          evidence: ['parentOf: $package'],
        ),
    ];

    final blockers = <String>[];
    if (importedFiles.isNotEmpty) {
      blockers.add('source imports reference $package');
    }
    if (transitiveUsers.isNotEmpty && !isDirect) {
      blockers.add('other packages depend on $package');
    }
    if (isDirect && descendants.isNotEmpty) {
      blockers
          .add('removing may drop ${descendants.length} transitive packages');
    }

    final safe = importedFiles.isEmpty && transitiveUsers.isEmpty && isDirect;

    final diagnostics = <Diagnostic>[
      if (!safe)
        Diagnostic(
          code: DiagnosticCodes.impactWarning,
          title: 'Removal may be unsafe',
          message:
              'Removing "$package" is not clearly safe from local evidence.',
          severity: DiagnosticSeverity.warning,
          package: package,
          evidence: blockers,
          remediation: 'Keep the dependency or update importers first.',
        ),
    ];

    return ImpactReport(
      simulation: simulation,
      affectedPackages: affected,
      affectedPaths: [
        for (final p in paths)
          AffectedPath(path: p, reason: 'Depends on removal target'),
      ],
      safeToApply: safe,
      summary: safe
          ? 'Removal of $package appears safe (no imports / reverse deps).'
          : 'Removal of $package has ${blockers.length} safety concern(s).',
      diagnostics: diagnostics,
    );
  }

  /// Best-effort impact of upgrading outdated direct deps (local graph only).
  ImpactReport upgradeAll() {
    final simulation = const ChangeSimulation(
      kind: ChangeSimulationKind.upgradeAll,
    );
    final directs =
        workspace.pubspec.allDependencies.map((d) => d.name).toSet();
    final affected = <AffectedPackage>[];
    final paths = <AffectedPath>[];
    for (final name in directs) {
      final parents = workspace.graph.parentsOf(name);
      affected.add(
        AffectedPackage(
          name: name,
          reason: 'Direct dependency included in upgrade-all simulation',
          isDirect: true,
          evidence: [
            if (workspace.lockfile?[name] != null)
              'locked: ${workspace.lockfile![name]!.version}',
            'parents: ${parents.length}',
          ],
        ),
      );
      for (final p in workspace.graph.pathsTo(name, limit: 4)) {
        paths.add(AffectedPath(path: p, reason: 'Direct dep path'));
      }
    }

    return ImpactReport(
      simulation: simulation,
      affectedPackages: affected,
      affectedPaths: paths.take(50).toList(),
      safeToApply: false,
      summary:
          'Upgrade-all simulation covers ${directs.length} direct dependencies. '
          'Use `pubdoctor outdated` for version evidence.',
      diagnostics: [
        Diagnostic(
          code: DiagnosticCodes.impactWarning,
          title: 'Upgrade-all is a simulation',
          message: 'Local graph impact only — not a pub solver dry-run.',
          severity: DiagnosticSeverity.info,
          evidence: ['directCount: ${directs.length}'],
        ),
      ],
    );
  }
}
