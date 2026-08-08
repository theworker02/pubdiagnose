import '../models/diagnostics.dart';
import '../models/metadata.dart';

/// Overall project health classification.
enum HealthStatus {
  /// No notable issues.
  healthy,

  /// Warnings or informational findings need attention.
  attentionRequired,

  /// Errors or critical findings.
  unhealthy,
}

/// Aggregated local dependency health report.
class HealthReport {
  /// Creates a health report.
  const HealthReport({
    required this.projectName,
    required this.status,
    required this.directDependencyCount,
    required this.devDependencyCount,
    required this.transitiveDependencyCount,
    required this.overrideCount,
    required this.outdatedCount,
    required this.constrainedUpgradeCount,
    required this.conflictCount,
    required this.diagnostics,
    this.hasLockfile = true,
    this.summary,
    this.outdated = const [],
  });

  /// Root package name.
  final String projectName;

  /// Roll-up status.
  final HealthStatus status;

  /// Declared production dependencies.
  final int directDependencyCount;

  /// Declared dev dependencies.
  final int devDependencyCount;

  /// Transitive packages (lockfile).
  final int transitiveDependencyCount;

  /// Override entries.
  final int overrideCount;

  /// Packages with newer versions available.
  final int outdatedCount;

  /// Packages with a compatible constrained upgrade.
  final int constrainedUpgradeCount;

  /// Empty-intersection conflicts.
  final int conflictCount;

  /// Whether a lockfile was present.
  final bool hasLockfile;

  /// Human summary line.
  final String? summary;

  /// Combined diagnostics.
  final List<Diagnostic> diagnostics;

  /// Outdated package details when collected.
  final List<OutdatedPackage> outdated;

  /// Highest severity among diagnostics (or info if empty).
  DiagnosticSeverity get maxSeverity {
    var max = DiagnosticSeverity.info;
    for (final d in diagnostics) {
      if (d.severity.index > max.index) max = d.severity;
    }
    return max;
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'project': projectName,
        'status': status.name,
        'summary': summary,
        'counts': {
          'directDependencies': directDependencyCount,
          'devDependencies': devDependencyCount,
          'transitiveDependencies': transitiveDependencyCount,
          'overrides': overrideCount,
          'outdated': outdatedCount,
          'constrainedUpgrades': constrainedUpgradeCount,
          'conflicts': conflictCount,
          'diagnostics': diagnostics.length,
        },
        'hasLockfile': hasLockfile,
        'diagnostics': [for (final d in diagnostics) d.toJson()],
        if (outdated.isNotEmpty)
          'outdated': [for (final o in outdated) o.toJson()],
      };
}

/// Confidence that a dependency is unused.
enum UnusedConfidence {
  /// Strong evidence (no imports, not a known tooling package).
  high,

  /// Plausible but may be used indirectly / by generators.
  medium,

  /// Speculative — do not treat as actionable alone.
  low,
}

/// A declared dependency that may be unused.
class UnusedDependencyFinding {
  /// Creates a finding.
  const UnusedDependencyFinding({
    required this.package,
    required this.section,
    required this.confidence,
    required this.reasons,
  });

  /// Package name.
  final String package;

  /// `dependencies` or `dev_dependencies`.
  final String section;

  /// Confidence.
  final UnusedConfidence confidence;

  /// Evidence / caveats.
  final List<String> reasons;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'section': section,
        'confidence': confidence.name,
        'reasons': reasons,
      };
}

/// A direct `package:` import of an undeclared package.
class UndeclaredImportFinding {
  /// Creates a finding.
  const UndeclaredImportFinding({
    required this.package,
    required this.files,
    required this.isDevContext,
    this.transitiveOnly = true,
  });

  /// Imported package.
  final String package;

  /// Source files that import it.
  final List<String> files;

  /// Whether imports were only seen under test/tool contexts.
  final bool isDevContext;

  /// Whether the package appears only as transitive in the lockfile.
  final bool transitiveOnly;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'files': files,
        'isDevContext': isDevContext,
        'transitiveOnly': transitiveOnly,
      };
}
