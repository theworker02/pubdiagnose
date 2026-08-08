import 'package:pub_semver/pub_semver.dart';

import 'diagnostics.dart';

/// Classification of a dependency override.
enum OverrideClassification {
  /// Still required to satisfy resolution.
  necessary,

  /// Likely removable.
  possiblyUnnecessary,

  /// Risky (pins older, forces incompatible, etc.).
  unsafe,

  /// Not enough information.
  unknown,
}

/// Analysis of a single `dependency_overrides` entry.
class OverrideAnalysis {
  /// Creates an override analysis.
  const OverrideAnalysis({
    required this.package,
    required this.classification,
    required this.explanation,
    this.declaredConstraint,
    this.resolvedVersion,
    this.wouldResolveWithout,
  });

  /// Overridden package.
  final String package;

  /// Classification.
  final OverrideClassification classification;

  /// Human explanation.
  final String explanation;

  /// Override constraint / source summary.
  final String? declaredConstraint;

  /// Currently resolved version.
  final Version? resolvedVersion;

  /// Best-effort guess of what would resolve without the override.
  final String? wouldResolveWithout;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'classification': classification.name,
        'explanation': explanation,
        if (declaredConstraint != null)
          'declaredConstraint': declaredConstraint,
        if (resolvedVersion != null)
          'resolvedVersion': resolvedVersion.toString(),
        if (wouldResolveWithout != null)
          'wouldResolveWithout': wouldResolveWithout,
      };
}

/// Confidence in a recommendation.
enum RecommendationConfidence {
  /// Strong evidence.
  high,

  /// Reasonable evidence with caveats.
  medium,

  /// Speculative.
  low,
}

/// Kind of recommendation.
enum RecommendationType {
  /// Loosen a constraint.
  loosenConstraint,

  /// Upgrade a direct dependency.
  upgradeDependency,

  /// Remove an override.
  removeOverride,

  /// Keep an override.
  keepOverride,

  /// Change SDK constraint.
  adjustSdk,

  /// Migrate / replace a package.
  migrate,

  /// Informational note.
  info,
}

/// Risk label for a proposed change.
enum ChangeRisk {
  /// Unlikely to break API usage based on semver.
  safe,

  /// May include breaking changes.
  potentiallyBreaking,

  /// Impact unknown.
  unknownImpact,
}

/// A concrete proposed change.
class ProposedChange {
  /// Creates a proposed change.
  const ProposedChange({
    required this.package,
    required this.description,
    required this.risk,
    this.from,
    this.to,
    this.file = 'pubspec.yaml',
  });

  /// Affected package.
  final String package;

  /// What to change.
  final String description;

  /// Risk label.
  final ChangeRisk risk;

  /// Current value.
  final String? from;

  /// Suggested value.
  final String? to;

  /// File to edit (guidance only — pubdoctor does not auto-edit).
  final String file;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'description': description,
        'risk': risk.name,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'file': file,
      };
}

/// An evidence-based recommendation.
class Recommendation {
  /// Creates a recommendation.
  const Recommendation({
    required this.type,
    required this.severity,
    required this.package,
    required this.explanation,
    required this.confidence,
    this.changes = const [],
    this.evidence = const [],
  });

  /// Recommendation type.
  final RecommendationType type;

  /// Severity.
  final DiagnosticSeverity severity;

  /// Primary package.
  final String package;

  /// Explanation.
  final String explanation;

  /// Confidence.
  final RecommendationConfidence confidence;

  /// Proposed changes.
  final List<ProposedChange> changes;

  /// Supporting evidence.
  final List<String> evidence;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'package': package,
        'explanation': explanation,
        'confidence': confidence.name,
        if (changes.isNotEmpty)
          'changes': changes.map((c) => c.toJson()).toList(),
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}
