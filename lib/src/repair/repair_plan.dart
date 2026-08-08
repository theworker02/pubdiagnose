import '../healing/healing_policy.dart';

/// Repair confidence.
enum RepairConfidence {
  /// Certain.
  certain,

  /// High.
  high,

  /// Medium.
  medium,

  /// Low.
  low,

  /// Unknown.
  unknown,
}

/// A repair candidate.
class RepairCandidate {
  /// Creates a candidate.
  const RepairCandidate({
    required this.id,
    required this.diagnosticCode,
    required this.description,
    required this.confidence,
    required this.tier,
    this.package,
    this.file,
    this.operations = const [],
    this.ambiguous = false,
  });

  /// Candidate id.
  final String id;

  /// Related diagnostic.
  final String diagnosticCode;

  /// Description.
  final String description;

  /// Confidence.
  final RepairConfidence confidence;

  /// Safety tier.
  final SafetyTier tier;

  /// Package.
  final String? package;

  /// File.
  final String? file;

  /// Operations.
  final List<RepairOperation> operations;

  /// Ambiguous — refuse auto.
  final bool ambiguous;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'diagnosticCode': diagnosticCode,
        'description': description,
        'confidence': confidence.name,
        'tier': tier.name,
        if (package != null) 'package': package,
        if (file != null) 'file': file,
        'ambiguous': ambiguous,
        'operations': [for (final o in operations) o.toJson()],
      };
}

/// A single file/metadata mutation.
class RepairOperation {
  /// Creates an operation.
  const RepairOperation({
    required this.kind,
    required this.target,
    required this.detail,
  });

  /// Kind: add_dependency, move_dependency, rewrite_import, …
  final String kind;

  /// Target path or package.
  final String target;

  /// Detail.
  final String detail;

  /// JSON.
  Map<String, Object?> toJson() => {
        'kind': kind,
        'target': target,
        'detail': detail,
      };
}

/// Aggregated repair plan.
class RepairPlan {
  /// Creates a plan.
  const RepairPlan({
    required this.id,
    required this.candidates,
    this.summary,
  });

  /// Plan id.
  final String id;

  /// Candidates.
  final List<RepairCandidate> candidates;

  /// Summary.
  final String? summary;

  /// Safe auto-applicable subset.
  List<RepairCandidate> get safeCandidates => [
        for (final c in candidates)
          if (!c.ambiguous &&
              (c.confidence == RepairConfidence.certain ||
                  c.confidence == RepairConfidence.high) &&
              (c.tier == SafetyTier.t1Metadata ||
                  c.tier == SafetyTier.t0Internal))
            c,
      ];

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        if (summary != null) 'summary': summary,
        'candidateCount': candidates.length,
        'candidates': [for (final c in candidates) c.toJson()],
      };
}
