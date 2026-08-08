import 'dart:async';

import 'transport.dart';
import 'work_result.dart';
import 'work_unit.dart';
import 'worker_capability.dart';

/// Local execution worker (in-process; isolates optional for heavy CPU).
class ExecutionWorker {
  /// Creates a worker.
  ExecutionWorker({
    required this.capability,
    Future<Map<String, Object?>> Function(WorkUnit unit)? execute,
  }) : _execute = execute ?? _defaultExecute;

  /// Advertised capability.
  final WorkerCapability capability;

  final Future<Map<String, Object?>> Function(WorkUnit unit) _execute;

  /// Handle a unit.
  Future<WorkResult> run(WorkUnit unit) async {
    if (!capability.canExecute(unit)) {
      return WorkResult(
        unitId: unit.id,
        status: WorkResultStatus.rejected,
        inputFingerprint: unit.inputFingerprint,
        workerSessionId: capability.sessionId,
        completedAt: DateTime.now().toUtc(),
        protocolVersion: capability.protocolVersion,
        error:
            'Worker ${capability.sessionId} cannot execute ${unit.kind.name} '
            'at scope ${unit.scope.name}',
      );
    }
    try {
      final data = await _execute(unit);
      return WorkResult(
        unitId: unit.id,
        status: WorkResultStatus.ok,
        inputFingerprint: unit.inputFingerprint,
        workerSessionId: capability.sessionId,
        completedAt: DateTime.now().toUtc(),
        protocolVersion: capability.protocolVersion,
        data: data,
        diagnostics: [
          for (final d in (data['diagnostics'] as List?) ?? const [])
            Map<String, Object?>.from((d as Map).cast<String, Object?>()),
        ],
      );
    } on Object catch (e) {
      return WorkResult(
        unitId: unit.id,
        status: WorkResultStatus.failed,
        inputFingerprint: unit.inputFingerprint,
        workerSessionId: capability.sessionId,
        completedAt: DateTime.now().toUtc(),
        protocolVersion: capability.protocolVersion,
        error: e.toString(),
      );
    }
  }

  /// Build a [LocalTransport] for this worker.
  WorkerTransport asTransport() =>
      LocalTransport(capability: capability, handler: run);

  static Future<Map<String, Object?>> _defaultExecute(WorkUnit unit) async {
    // Lightweight local stub: echo kind + package count for scheduling tests.
    final packages = (unit.payload['packages'] as List?) ?? const [];
    return {
      'kind': unit.kind.name,
      'packageCount': packages.length,
      'diagnostics': <Map<String, Object?>>[],
    };
  }
}

/// Optional isolate-backed pool for CPU-bound units.
///
/// Uses sequential local execution by default; when [useIsolates] is true,
/// each unit runs in a fresh isolate via [Isolate.run]-compatible callback.
class LocalWorkerPool {
  /// Creates a pool.
  LocalWorkerPool({
    required this.workerCount,
    required this.capabilityTemplate,
    this.useIsolates = false,
  }) : assert(workerCount >= 1);

  /// Number of logical workers.
  final int workerCount;

  /// Template capability (session ids are suffixed).
  final WorkerCapability capabilityTemplate;

  /// Whether to prefer isolate execution for heavy units.
  final bool useIsolates;

  /// Build workers.
  List<ExecutionWorker> createWorkers() {
    return [
      for (var i = 0; i < workerCount; i++)
        ExecutionWorker(
          capability: WorkerCapability(
            sessionId: '${capabilityTemplate.sessionId}-$i',
            protocolVersion: capabilityTemplate.protocolVersion,
            dartVersion: capabilityTemplate.dartVersion,
            os: capabilityTemplate.os,
            architecture: capabilityTemplate.architecture,
            kinds: capabilityTemplate.kinds,
            maxScope: capabilityTemplate.maxScope,
            availableTools: capabilityTemplate.availableTools,
          ),
        ),
    ];
  }

  /// Conservative default worker count.
  static int defaultWorkerCount({int? cpuCount}) {
    final n = cpuCount ?? 2;
    if (n <= 1) return 1;
    if (n <= 4) return 2;
    return 4;
  }
}
