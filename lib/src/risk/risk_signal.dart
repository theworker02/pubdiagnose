/// Evidence-backed risk category (no opaque numeric scores).
enum RiskCategory {
  /// Little evidence of risk.
  low,

  /// Some concerning evidence.
  moderate,

  /// Strong evidence of material risk.
  high,

  /// Blocking / severe risk.
  critical,

  /// Insufficient evidence to classify.
  unknown,
}

/// Confidence in a risk signal's evidence.
enum RiskConfidence {
  /// Strong factual evidence.
  high,

  /// Partial or inferred evidence.
  medium,

  /// Weak / incomplete evidence.
  low,
}

/// A single evidence-driven risk signal for a package or graph.
class RiskSignal {
  /// Creates a risk signal.
  const RiskSignal({
    required this.id,
    required this.category,
    required this.confidence,
    required this.title,
    required this.message,
    required this.evidence,
    this.package,
    this.remediation,
  });

  /// Stable signal id (e.g. `discontinued`, `stale_sdk`).
  final String id;

  /// Risk category.
  final RiskCategory category;

  /// Confidence in the evidence.
  final RiskConfidence confidence;

  /// Short title.
  final String title;

  /// Human-readable message.
  final String message;

  /// Factual evidence strings.
  final List<String> evidence;

  /// Affected package, if any.
  final String? package;

  /// Optional remediation guidance.
  final String? remediation;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'confidence': confidence.name,
        'title': title,
        'message': message,
        'evidence': evidence,
        if (package != null) 'package': package,
        if (remediation != null) 'remediation': remediation,
      };
}
