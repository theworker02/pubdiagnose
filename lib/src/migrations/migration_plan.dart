import '../serialization/schema_version.dart';
import 'migration_graph.dart';
import 'migration_risk.dart';
import 'migration_step.dart';

/// Kind of migration target.
enum MigrationTargetKind {
  /// Dart SDK target.
  dartSdk,

  /// Flutter SDK target.
  flutterSdk,

  /// Hosted package version target.
  package,
}

/// Persisted / in-memory migration plan.
class MigrationPlan {
  /// Creates a migration plan.
  MigrationPlan({
    required this.id,
    required this.targetKind,
    required this.target,
    required this.steps,
    required this.createdAt,
    this.package,
    this.status = 'active',
    this.updatedAt,
  });

  /// Plan id.
  final String id;

  /// Target kind.
  final MigrationTargetKind targetKind;

  /// Target version string (SDK or package version).
  final String target;

  /// Package name when [targetKind] is package.
  final String? package;

  /// Ordered steps.
  final List<MigrationStep> steps;

  /// Status: active, completed, aborted.
  final String status;

  /// Creation time.
  final DateTime createdAt;

  /// Last update.
  final DateTime? updatedAt;

  /// Graph view.
  MigrationGraph get graph => MigrationGraph.fromSteps(steps);

  /// Overall risk = worst step risk.
  MigrationRiskLevel get overallRisk {
    var worst = MigrationRiskLevel.low;
    var rank = 0;
    for (final s in steps) {
      final r = switch (s.risk.level) {
        MigrationRiskLevel.blocked => 4,
        MigrationRiskLevel.high => 3,
        MigrationRiskLevel.moderate => 2,
        MigrationRiskLevel.unknown => 1,
        MigrationRiskLevel.low => 0,
      };
      if (r > rank) {
        rank = r;
        worst = s.risk.level;
      }
    }
    return worst;
  }

  /// Copy with updated steps/status.
  MigrationPlan copyWith({
    List<MigrationStep>? steps,
    String? status,
    DateTime? updatedAt,
  }) {
    return MigrationPlan(
      id: id,
      targetKind: targetKind,
      target: target,
      package: package,
      steps: steps ?? this.steps,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': SchemaVersions.migrations,
        'id': id,
        'targetKind': targetKind.name,
        'target': target,
        if (package != null) 'package': package,
        'status': status,
        'overallRisk': overallRisk.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        'steps': [for (final s in steps) s.toJson()],
      };

  /// Parse from JSON.
  factory MigrationPlan.fromJson(Map<String, Object?> json) {
    final kind = MigrationTargetKind.values.firstWhere(
      (e) => e.name == json['targetKind'],
      orElse: () => MigrationTargetKind.package,
    );
    return MigrationPlan(
      id: json['id']! as String,
      targetKind: kind,
      target: json['target']! as String,
      package: json['package'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']! as String)
          : null,
      steps: [
        for (final s in (json['steps'] as List? ?? const []))
          MigrationStep.fromJson(Map<String, Object?>.from(s as Map)),
      ],
    );
  }
}
