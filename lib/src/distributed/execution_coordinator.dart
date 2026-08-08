import 'scheduler.dart';
import 'transport.dart';
import 'work_result.dart';
import 'work_unit.dart';
import 'worker_capability.dart';

/// Verification failure reasons for distributed results.
enum ResultVerificationFailure {
  /// Protocol mismatch.
  schemaIncompatible,

  /// Fingerprint does not match the submitted unit.
  fingerprintMismatch,

  /// Unknown worker session.
  unknownWorker,

  /// Result older than session start / stale.
  stale,

  /// Malformed / incomplete payload.
  malformed,

  /// Unit id unknown.
  unknownUnit,
}

/// Outcome of verifying a [WorkResult].
class ResultVerification {
  /// Creates a verification outcome.
  const ResultVerification({
    required this.accepted,
    this.failure,
    this.message,
  });

  /// Whether the coordinator accepts the result.
  final bool accepted;

  /// Failure kind when rejected.
  final ResultVerificationFailure? failure;

  /// Human message.
  final String? message;

  /// JSON.
  Map<String, Object?> toJson() => {
        'accepted': accepted,
        if (failure != null) 'failure': failure!.name,
        if (message != null) 'message': message,
      };
}

/// Coordinates distributed analysis across local/remote workers.
class ExecutionCoordinator {
  /// Creates a coordinator.
  ExecutionCoordinator({
    required this.transports,
    DateTime? sessionStartedAt,
    this.maxResultAge = const Duration(minutes: 30),
  }) : sessionStartedAt = sessionStartedAt ?? DateTime.now().toUtc();

  /// Worker transports keyed later by session id after handshake.
  final List<WorkerTransport> transports;

  /// When this coordination session started.
  final DateTime sessionStartedAt;

  /// Reject results older than this relative to now, or before session start.
  final Duration maxResultAge;

  final Map<String, WorkerTransport> _bySession = {};
  final Map<String, WorkerCapability> _caps = {};
  final Map<String, WorkUnit> _submitted = {};

  /// Handshake all transports.
  Future<List<WorkerCapability>> connect() async {
    _bySession.clear();
    _caps.clear();
    for (final t in transports) {
      final cap = await t.handshake();
      _bySession[cap.sessionId] = t;
      _caps[cap.sessionId] = cap;
    }
    return _caps.values.toList();
  }

  /// Schedule and run [units], verifying each result.
  Future<CoordinatorRunResult> run(List<WorkUnit> units) async {
    if (_caps.isEmpty) await connect();
    final scheduler = WorkScheduler();
    final assignments = scheduler.schedule(
      units: units,
      workers: _caps.values.toList(),
    );
    final accepted = <WorkResult>[];
    final rejected = <WorkResult>[];
    final verifications = <String, ResultVerification>{};

    for (final a in assignments) {
      _submitted[a.unit.id] = a.unit;
      final transport = _bySession[a.workerSessionId];
      if (transport == null) {
        final fake = WorkResult(
          unitId: a.unit.id,
          status: WorkResultStatus.invalid,
          inputFingerprint: a.unit.inputFingerprint,
          workerSessionId: a.workerSessionId,
          completedAt: DateTime.now().toUtc(),
          error: 'Worker disappeared',
        );
        rejected.add(fake);
        verifications[a.unit.id] = const ResultVerification(
          accepted: false,
          failure: ResultVerificationFailure.unknownWorker,
          message: 'Worker disappeared before submit',
        );
        continue;
      }
      WorkResult result;
      try {
        result = await transport.submit(a.unit);
      } on Object catch (e) {
        result = WorkResult(
          unitId: a.unit.id,
          status: WorkResultStatus.failed,
          inputFingerprint: a.unit.inputFingerprint,
          workerSessionId: a.workerSessionId,
          completedAt: DateTime.now().toUtc(),
          error: e.toString(),
        );
      }
      final v = verify(result);
      verifications[a.unit.id] = v;
      if (v.accepted && result.status == WorkResultStatus.ok) {
        accepted.add(result);
      } else {
        rejected.add(
          WorkResult(
            unitId: result.unitId,
            status: WorkResultStatus.invalid,
            inputFingerprint: result.inputFingerprint,
            workerSessionId: result.workerSessionId,
            completedAt: result.completedAt,
            protocolVersion: result.protocolVersion,
            diagnostics: result.diagnostics,
            data: result.data,
            error: v.message ?? result.error,
          ),
        );
      }
    }

    return CoordinatorRunResult(
      accepted: accepted,
      rejected: rejected,
      verifications: verifications,
      workerCount: _caps.length,
    );
  }

  /// Verify a result against submitted units and session trust rules.
  ResultVerification verify(WorkResult result) {
    final unit = _submitted[result.unitId];
    if (unit == null) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.unknownUnit,
        message: 'Unknown unit id',
      );
    }
    if (!_caps.containsKey(result.workerSessionId)) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.unknownWorker,
        message: 'Unknown worker session',
      );
    }
    if (result.protocolVersion != unit.protocolVersion) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.schemaIncompatible,
        message: 'Protocol version mismatch',
      );
    }
    if (result.inputFingerprint != unit.inputFingerprint) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.fingerprintMismatch,
        message: 'Input fingerprint mismatch (stale or wrong inputs)',
      );
    }
    final now = DateTime.now().toUtc();
    if (result.completedAt.isBefore(sessionStartedAt) ||
        now.difference(result.completedAt) > maxResultAge) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.stale,
        message: 'Stale analysis result rejected',
      );
    }
    if (result.status == WorkResultStatus.ok &&
        result.data.isEmpty &&
        result.diagnostics.isEmpty &&
        result.error != null) {
      return const ResultVerification(
        accepted: false,
        failure: ResultVerificationFailure.malformed,
        message: 'Malformed ok result',
      );
    }
    return const ResultVerification(accepted: true);
  }

  /// Close transports.
  Future<void> close() async {
    for (final t in transports) {
      await t.close();
    }
  }
}

/// Aggregated run result.
class CoordinatorRunResult {
  /// Creates a run result.
  const CoordinatorRunResult({
    required this.accepted,
    required this.rejected,
    required this.verifications,
    required this.workerCount,
  });

  /// Accepted results.
  final List<WorkResult> accepted;

  /// Rejected / invalid results.
  final List<WorkResult> rejected;

  /// Per-unit verification.
  final Map<String, ResultVerification> verifications;

  /// Worker count.
  final int workerCount;

  /// JSON.
  Map<String, Object?> toJson() => {
        'workerCount': workerCount,
        'accepted': [for (final r in accepted) r.toJson()],
        'rejected': [for (final r in rejected) r.toJson()],
        'verifications': {
          for (final e in verifications.entries) e.key: e.value.toJson(),
        },
      };
}
