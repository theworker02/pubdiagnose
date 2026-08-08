import 'work_unit.dart';
import 'worker_capability.dart';

/// Assignment of a work unit to a worker session.
class ScheduledAssignment {
  /// Creates an assignment.
  const ScheduledAssignment({
    required this.unit,
    required this.workerSessionId,
  });

  /// Unit.
  final WorkUnit unit;

  /// Target worker.
  final String workerSessionId;
}

/// Schedules work units onto capable workers.
class WorkScheduler {
  /// Round-robin / capability-aware scheduling.
  List<ScheduledAssignment> schedule({
    required List<WorkUnit> units,
    required List<WorkerCapability> workers,
  }) {
    if (workers.isEmpty) return const [];
    final assignments = <ScheduledAssignment>[];
    var cursor = 0;
    for (final unit in units) {
      WorkerCapability? chosen;
      for (var i = 0; i < workers.length; i++) {
        final idx = (cursor + i) % workers.length;
        final w = workers[idx];
        if (w.canExecute(unit)) {
          chosen = w;
          cursor = (idx + 1) % workers.length;
          break;
        }
      }
      if (chosen == null) continue;
      assignments.add(
        ScheduledAssignment(unit: unit, workerSessionId: chosen.sessionId),
      );
    }
    return assignments;
  }

  /// Split independent check work into units (conservative).
  static List<WorkUnit> planCheckUnits({
    required String workspaceFingerprint,
    required List<String> packageNames,
    int maxPackagesPerUnit = 32,
  }) {
    final units = <WorkUnit>[];
    for (var i = 0; i < packageNames.length; i += maxPackagesPerUnit) {
      final slice = packageNames.sublist(
        i,
        i + maxPackagesPerUnit > packageNames.length
            ? packageNames.length
            : i + maxPackagesPerUnit,
      );
      units.add(
        WorkUnit(
          id: 'risk-$i',
          kind: WorkUnitKind.riskAnalysis,
          inputFingerprint: '$workspaceFingerprint:risk:${slice.join(',')}',
          scope: TrustScope.dependencyModel,
          payload: {'packages': slice},
        ),
      );
    }
    units.add(
      WorkUnit(
        id: 'policy-0',
        kind: WorkUnitKind.policyEvaluation,
        inputFingerprint: '$workspaceFingerprint:policy',
        scope: TrustScope.dependencyModel,
        payload: const {},
      ),
    );
    return units;
  }
}
