import '../constraints/constraint_analyzer.dart';
import '../metadata/package_repository.dart';
import '../models/dependency_spec.dart';
import '../models/exceptions.dart';
import '../workspace/workspace_loader.dart';

/// Project-local explanation of a package for `pubdoctor explain <package>`.
class PackageExplanation {
  /// Creates an explanation.
  const PackageExplanation({
    required this.package,
    required this.present,
    this.version,
    this.dependencyKind,
    this.declaredSection,
    this.declaredConstraint,
    this.introducedBy = const [],
    this.shortestPath,
    this.latest,
    this.latestStable,
    this.isDiscontinued = false,
    this.replacedBy,
    this.overrideSummary,
    this.sdkConstraint,
    this.blockers = const [],
    this.notes = const [],
    this.offline = false,
  });

  /// Package name.
  final String package;

  /// Whether found locally.
  final bool present;

  /// Resolved version.
  final String? version;

  /// Lockfile kind.
  final String? dependencyKind;

  /// Declared section if direct.
  final String? declaredSection;

  /// Declared constraint if direct.
  final String? declaredConstraint;

  /// Parent packages.
  final List<String> introducedBy;

  /// Shortest path display.
  final String? shortestPath;

  /// Latest from repository.
  final String? latest;

  /// Latest stable from repository.
  final String? latestStable;

  /// Discontinued flag.
  final bool isDiscontinued;

  /// Replacement package.
  final String? replacedBy;

  /// Override summary if any.
  final String? overrideSummary;

  /// SDK constraint of locked version when known.
  final String? sdkConstraint;

  /// Upgrade blockers toward latest stable.
  final List<String> blockers;

  /// Extra notes.
  final List<String> notes;

  /// True when repository metadata was unavailable.
  final bool offline;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'present': present,
        if (version != null) 'version': version,
        if (dependencyKind != null) 'dependencyKind': dependencyKind,
        if (declaredSection != null) 'declaredSection': declaredSection,
        if (declaredConstraint != null)
          'declaredConstraint': declaredConstraint,
        'introducedBy': introducedBy,
        if (shortestPath != null) 'shortestPath': shortestPath,
        if (latest != null) 'latest': latest,
        if (latestStable != null) 'latestStable': latestStable,
        'isDiscontinued': isDiscontinued,
        if (replacedBy != null) 'replacedBy': replacedBy,
        if (overrideSummary != null) 'overrideSummary': overrideSummary,
        if (sdkConstraint != null) 'sdkConstraint': sdkConstraint,
        'blockers': blockers,
        'notes': notes,
        'offline': offline,
      };
}

/// Builds [PackageExplanation] values.
class PackageExplainer {
  /// Creates an explainer.
  PackageExplainer({
    required this.workspace,
    this.repository,
  });

  /// Workspace.
  final PubWorkspace workspace;

  /// Optional repository (offline if null / failing).
  final PackageRepository? repository;

  /// Explain [package].
  Future<PackageExplanation> explain(String package) async {
    final node = workspace.graph.package(package);
    final spec = workspace.pubspec.dependency(package);
    final override = workspace.pubspec.overrideFor(package);
    final locked = workspace.lockfile?[package];

    if (node == null && spec == null && override == null && locked == null) {
      return PackageExplanation(
        package: package,
        present: false,
        notes: [
          'Package "$package" was not found in pubspec.yaml or the '
              'dependency graph.',
        ],
      );
    }

    final parents = workspace.graph.parentsOf(package);
    final path = workspace.graph.shortestPathTo(package);

    String? declaredSection;
    if (spec != null) {
      declaredSection = spec.section == DependencySection.devDependency
          ? 'dev_dependencies'
          : 'dependencies';
    }

    final notes = <String>[];
    var offline = false;
    String? latest;
    String? latestStable;
    var discontinued = false;
    String? replacedBy;
    String? sdkConstraint;
    final blockers = <String>[];

    final repo = repository;
    if (repo != null && (locked != null || spec != null)) {
      try {
        final meta = await repo.getPackage(package);
        latest = meta.latest?.toString();
        latestStable = meta.latestStable?.toString();
        discontinued = meta.isDiscontinued;
        replacedBy = meta.replacedBy;
        notes.addAll(meta.factualNotes);
        if (locked != null) {
          sdkConstraint =
              meta.versionInfo(locked.version)?.sdkConstraint?.toString();
        }
        if (meta.latestStable != null &&
            locked != null &&
            meta.latestStable! > locked.version) {
          final reqs =
              ConstraintAnalyzer(workspace).collectRequirements()[package] ??
                  const [];
          for (final r in reqs) {
            if (!r.constraint.allows(meta.latestStable!)) {
              blockers.add(
                '${r.requiredBy} requires ${r.constraint} '
                '(via ${r.path.display})',
              );
            }
          }
        }
      } on PackageRepositoryException {
        offline = true;
        notes.add('Package repository unreachable — local graph data only.');
      }
    }

    return PackageExplanation(
      package: package,
      present: true,
      version: (node?.version ?? locked?.version)?.toString(),
      dependencyKind: node?.dependencyKind ?? locked?.dependency,
      declaredSection: declaredSection,
      declaredConstraint: spec?.constraint.toString(),
      introducedBy: parents,
      shortestPath: path?.display,
      latest: latest,
      latestStable: latestStable,
      isDiscontinued: discontinued,
      replacedBy: replacedBy,
      overrideSummary: override == null
          ? null
          : '${override.source.name} ${override.constraint}',
      sdkConstraint: sdkConstraint,
      blockers: blockers,
      notes: notes,
      offline: offline,
    );
  }
}
