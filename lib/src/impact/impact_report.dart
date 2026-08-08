import '../models/diagnostics.dart';
import '../models/graph_models.dart';

/// A package affected by a proposed change.
class AffectedPackage {
  /// Creates an affected package entry.
  const AffectedPackage({
    required this.name,
    required this.reason,
    this.isDirect = false,
    this.importsPackage = false,
    this.isWorkspaceMember = false,
    this.evidence = const [],
  });

  /// Package name.
  final String name;

  /// Why it is affected.
  final String reason;

  /// Direct dependency of root.
  final bool isDirect;

  /// Source imports this package.
  final bool importsPackage;

  /// Workspace member reference.
  final bool isWorkspaceMember;

  /// Evidence.
  final List<String> evidence;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        'reason': reason,
        'isDirect': isDirect,
        'importsPackage': importsPackage,
        'isWorkspaceMember': isWorkspaceMember,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}

/// A dependency path affected by a change.
class AffectedPath {
  /// Creates an affected path.
  const AffectedPath({
    required this.path,
    required this.reason,
  });

  /// Path from root.
  final DependencyPath path;

  /// Why this path matters.
  final String reason;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'path': path.toJson(),
        'reason': reason,
      };
}

/// Simulated change kind.
enum ChangeSimulationKind {
  /// Upgrade a package to a version.
  upgradePackage,

  /// Remove a package.
  removePackage,

  /// Upgrade all outdated (best-effort local).
  upgradeAll,
}

/// Description of a simulated change.
class ChangeSimulation {
  /// Creates a simulation.
  const ChangeSimulation({
    required this.kind,
    this.package,
    this.version,
  });

  /// Kind.
  final ChangeSimulationKind kind;

  /// Package name.
  final String? package;

  /// Target version.
  final String? version;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (package != null) 'package': package,
        if (version != null) 'version': version,
      };
}

/// Impact analysis report.
class ImpactReport {
  /// Creates a report.
  const ImpactReport({
    required this.simulation,
    required this.affectedPackages,
    required this.affectedPaths,
    required this.safeToApply,
    this.diagnostics = const [],
    this.summary,
  });

  /// Simulated change.
  final ChangeSimulation simulation;

  /// Affected packages.
  final List<AffectedPackage> affectedPackages;

  /// Affected paths.
  final List<AffectedPath> affectedPaths;

  /// Whether removal/upgrade looks safe from local evidence.
  final bool safeToApply;

  /// Diagnostics.
  final List<Diagnostic> diagnostics;

  /// Summary.
  final String? summary;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'simulation': simulation.toJson(),
        'safeToApply': safeToApply,
        if (summary != null) 'summary': summary,
        'affectedPackageCount': affectedPackages.length,
        'affectedPackages': [for (final p in affectedPackages) p.toJson()],
        'affectedPaths': [for (final p in affectedPaths) p.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };
}
