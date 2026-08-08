import 'package:pubdiagnose/src/distributed/execution_coordinator.dart';
import 'package:pubdiagnose/src/distributed/execution_worker.dart';
import 'package:pubdiagnose/src/distributed/scheduler.dart';
import 'package:pubdiagnose/src/distributed/transport.dart';
import 'package:pubdiagnose/src/distributed/work_result.dart';
import 'package:pubdiagnose/src/distributed/work_unit.dart';
import 'package:pubdiagnose/src/distributed/worker_capability.dart';
import 'package:test/test.dart';

void main() {
  group('distributed', () {
    test('scheduler assigns capable workers', () {
      final workers = [
        WorkerCapability.local(
          sessionId: 'w0',
          dartVersion: '3.5.0',
          os: 'windows',
          architecture: 'x64',
        ),
      ];
      final units = WorkScheduler.planCheckUnits(
        workspaceFingerprint: 'app',
        packageNames: ['a', 'b', 'c'],
        maxPackagesPerUnit: 2,
      );
      final assignments =
          WorkScheduler().schedule(units: units, workers: workers);
      expect(assignments, isNotEmpty);
      expect(assignments.every((a) => a.workerSessionId == 'w0'), isTrue);
    });

    test('coordinator rejects stale / fingerprint mismatch', () async {
      final cap = WorkerCapability.local(
        sessionId: 'local-0',
        dartVersion: '3.5.0',
        os: 'linux',
        architecture: 'arm64',
      );
      final worker = ExecutionWorker(capability: cap);
      final coordinator = ExecutionCoordinator(
        transports: [worker.asTransport()],
        sessionStartedAt: DateTime.now().toUtc(),
      );
      await coordinator.connect();

      final unit = const WorkUnit(
        id: 'u1',
        kind: WorkUnitKind.policyEvaluation,
        inputFingerprint: 'fp-correct',
        scope: TrustScope.dependencyModel,
      );
      final result = await coordinator.run([unit]);
      expect(result.accepted, isNotEmpty);

      final c2 = ExecutionCoordinator(
        transports: [worker.asTransport()],
        maxResultAge: const Duration(minutes: 1),
      );
      await c2.connect();
      await c2.run([unit]);
      final forged = WorkResult(
        unitId: unit.id,
        status: WorkResultStatus.ok,
        inputFingerprint: 'fp-WRONG',
        workerSessionId: cap.sessionId,
        completedAt: DateTime.now().toUtc(),
        data: const {'ok': true},
      );
      final v = c2.verify(forged);
      expect(v.accepted, isFalse);
      expect(v.failure, ResultVerificationFailure.fingerprintMismatch);

      final stale = WorkResult(
        unitId: unit.id,
        status: WorkResultStatus.ok,
        inputFingerprint: 'fp-correct',
        workerSessionId: cap.sessionId,
        completedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
        data: const {'ok': true},
      );
      final staleV = c2.verify(stale);
      expect(staleV.accepted, isFalse);
      expect(staleV.failure, ResultVerificationFailure.stale);

      await coordinator.close();
      await c2.close();
    });

    test('remote protocol message compatibility', () {
      const msg = RemoteProtocolMessage(
        type: 'work',
        protocolVersion: WorkUnit.protocolVersionV1,
        body: {'id': '1'},
      );
      expect(msg.isCompatible(WorkUnit.protocolVersionV1), isTrue);
      expect(msg.isCompatible(99), isFalse);
    });

    test('worker disappears yields rejected result', () async {
      final cap = WorkerCapability.local(
        sessionId: 'gone',
        dartVersion: '3.5.0',
        os: 'linux',
        architecture: 'x64',
      );
      final disappearing = _DisappearingTransport(cap);
      final coordinator = ExecutionCoordinator(transports: [disappearing]);
      await coordinator.connect();
      // Remove transport mapping by using empty submit after handshake
      final units = [
        const WorkUnit(
          id: 'x',
          kind: WorkUnitKind.riskAnalysis,
          inputFingerprint: 'f',
          scope: TrustScope.metadataOnly,
        ),
      ];
      final run = await coordinator.run(units);
      expect(run.rejected, isNotEmpty);
      await coordinator.close();
    });
  });
}

class _DisappearingTransport implements WorkerTransport {
  _DisappearingTransport(this.capability);

  final WorkerCapability capability;

  @override
  Future<WorkerCapability> handshake() async => capability;

  @override
  Future<WorkResult> submit(WorkUnit unit) async {
    throw StateError('worker disappeared');
  }

  @override
  Future<void> close() async {}
}
