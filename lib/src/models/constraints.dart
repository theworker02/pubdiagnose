import 'package:pub_semver/pub_semver.dart';

import 'graph_models.dart';

/// Severity of a dependency conflict.
enum ConflictSeverity {
  /// Empty constraint intersection — unsatisfiable without overrides/changes.
  error,

  /// Extremely narrow intersection that is fragile.
  warning,

  /// Notable but not necessarily broken.
  info,
}

/// A single constraint contributed by a dependent package.
class ConstraintRequirement {
  /// Creates a constraint requirement.
  const ConstraintRequirement({
    required this.package,
    required this.requiredBy,
    required this.constraint,
    required this.path,
  });

  /// Package being constrained.
  final String package;

  /// Package that declared the constraint.
  final String requiredBy;

  /// Declared constraint.
  final VersionConstraint constraint;

  /// Path from project root to [requiredBy] (then conceptually to [package]).
  final DependencyPath path;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'requiredBy': requiredBy,
        'constraint': constraint.toString(),
        'path': path.toJson(),
      };
}

/// A structured conflict or narrow-intersection finding.
class DependencyConflict {
  /// Creates a conflict report.
  const DependencyConflict({
    required this.package,
    required this.requirements,
    required this.intersection,
    required this.severity,
    this.minimalIncompatible = const [],
    this.explanation,
  });

  /// Package with conflicting/narrow constraints.
  final String package;

  /// All known requirements.
  final List<ConstraintRequirement> requirements;

  /// Intersection of all requirements (`VersionConstraint.empty` if none).
  final VersionConstraint intersection;

  /// Severity.
  final ConflictSeverity severity;

  /// Minimal subset of requirements that are mutually incompatible.
  final List<ConstraintRequirement> minimalIncompatible;

  /// Human explanation.
  final String? explanation;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'severity': severity.name,
        'intersection': intersection.toString(),
        'requirements': requirements.map((r) => r.toJson()).toList(),
        if (minimalIncompatible.isNotEmpty)
          'minimalIncompatible':
              minimalIncompatible.map((r) => r.toJson()).toList(),
        if (explanation != null) 'explanation': explanation,
      };
}
