import 'migration_risk.dart';

/// Status of a migration step.
enum MigrationStepStatus {
  /// Not started.
  pending,

  /// Ready to apply (prerequisites met).
  ready,

  /// Completed.
  done,

  /// Skipped.
  skipped,

  /// Failed validation or apply.
  failed,
}

/// A single ordered migration action.
class MigrationStep {
  /// Creates a migration step.
  const MigrationStep({
    required this.id,
    required this.title,
    required this.description,
    required this.risk,
    this.package,
    this.fromVersion,
    this.toVersion,
    this.prerequisiteIds = const [],
    this.status = MigrationStepStatus.pending,
    this.evidence = const [],
  });

  /// Stable step id.
  final String id;

  /// Short title.
  final String title;

  /// What to do.
  final String description;

  /// Risk assessment.
  final MigrationRisk risk;

  /// Affected package, if any.
  final String? package;

  /// Current / from version.
  final String? fromVersion;

  /// Target version.
  final String? toVersion;

  /// Prerequisite step ids.
  final List<String> prerequisiteIds;

  /// Status.
  final MigrationStepStatus status;

  /// Evidence.
  final List<String> evidence;

  /// Copy with new fields.
  MigrationStep copyWith({
    MigrationStepStatus? status,
    MigrationRisk? risk,
  }) {
    return MigrationStep(
      id: id,
      title: title,
      description: description,
      risk: risk ?? this.risk,
      package: package,
      fromVersion: fromVersion,
      toVersion: toVersion,
      prerequisiteIds: prerequisiteIds,
      status: status ?? this.status,
      evidence: evidence,
    );
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'risk': risk.toJson(),
        if (package != null) 'package': package,
        if (fromVersion != null) 'fromVersion': fromVersion,
        if (toVersion != null) 'toVersion': toVersion,
        'prerequisiteIds': prerequisiteIds,
        'status': status.name,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };

  /// Parse from JSON.
  factory MigrationStep.fromJson(Map<String, Object?> json) {
    final riskRaw = json['risk'];
    final riskMap = riskRaw is Map
        ? Map<String, Object?>.from(riskRaw)
        : <String, Object?>{};
    return MigrationStep(
      id: json['id']! as String,
      title: json['title']! as String,
      description: json['description']! as String,
      risk: MigrationRisk(
        level: MigrationRiskLevel.values.firstWhere(
          (e) => e.name == riskMap['level'],
          orElse: () => MigrationRiskLevel.unknown,
        ),
        evidence: [
          for (final e in (riskMap['evidence'] as List? ?? const []))
            e.toString(),
        ],
        summary: riskMap['summary'] as String?,
      ),
      package: json['package'] as String?,
      fromVersion: json['fromVersion'] as String?,
      toVersion: json['toVersion'] as String?,
      prerequisiteIds: [
        for (final e in (json['prerequisiteIds'] as List? ?? const []))
          e.toString(),
      ],
      status: MigrationStepStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MigrationStepStatus.pending,
      ),
      evidence: [
        for (final e in (json['evidence'] as List? ?? const [])) e.toString(),
      ],
    );
  }
}
