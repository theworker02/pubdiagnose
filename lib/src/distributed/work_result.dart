import 'work_unit.dart';

/// Outcome status from a worker.
enum WorkResultStatus {
  /// Completed successfully.
  ok,

  /// Worker rejected the unit (capability / scope).
  rejected,

  /// Worker failed during execution.
  failed,

  /// Result failed coordinator verification.
  invalid,
}

/// Result returned by a worker for a [WorkUnit].
class WorkResult {
  /// Creates a result.
  const WorkResult({
    required this.unitId,
    required this.status,
    required this.inputFingerprint,
    required this.workerSessionId,
    required this.completedAt,
    this.protocolVersion = WorkUnit.protocolVersionV1,
    this.diagnostics = const [],
    this.data = const {},
    this.error,
  });

  /// Matching work unit id.
  final String unitId;

  /// Status.
  final WorkResultStatus status;

  /// Must match the unit's fingerprint.
  final String inputFingerprint;

  /// Worker session / identity.
  final String workerSessionId;

  /// Completion timestamp (UTC ISO-8601).
  final DateTime completedAt;

  /// Protocol version used by the worker.
  final int protocolVersion;

  /// Diagnostic maps produced by the unit.
  final List<Map<String, Object?>> diagnostics;

  /// Opaque structured payload.
  final Map<String, Object?> data;

  /// Error message when not ok.
  final String? error;

  /// JSON.
  Map<String, Object?> toJson() => {
        'unitId': unitId,
        'status': status.name,
        'inputFingerprint': inputFingerprint,
        'workerSessionId': workerSessionId,
        'completedAt': completedAt.toUtc().toIso8601String(),
        'protocolVersion': protocolVersion,
        'diagnostics': diagnostics,
        'data': data,
        if (error != null) 'error': error,
      };

  /// Parse from JSON.
  factory WorkResult.fromJson(Map<String, Object?> json) {
    final completedRaw = json['completedAt']?.toString();
    return WorkResult(
      unitId: json['unitId']! as String,
      status: WorkResultStatus.values.byName(json['status']! as String),
      inputFingerprint: json['inputFingerprint']! as String,
      workerSessionId: json['workerSessionId']! as String,
      completedAt: completedRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(completedRaw),
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ??
          WorkUnit.protocolVersionV1,
      diagnostics: [
        for (final d in (json['diagnostics'] as List?) ?? const [])
          Map<String, Object?>.from((d as Map).cast<String, Object?>()),
      ],
      data: Map<String, Object?>.from(
        (json['data'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      error: json['error']?.toString(),
    );
  }
}
