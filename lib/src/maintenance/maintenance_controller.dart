import '../models/diagnostics.dart';
import '../models/health.dart';
import 'maintenance_plan.dart';

/// Policy wrapper for maintenance modes.
class MaintenancePolicy {
  /// Creates a policy.
  const MaintenancePolicy({
    required this.mode,
    this.limits = MaintenanceLimits.defaults,
    this.repairHistory = false,
  });

  /// Mode.
  final MaintenanceMode mode;

  /// Limits.
  final MaintenanceLimits limits;

  /// Whether to scan repair history for regressions.
  final bool repairHistory;

  /// Effective limits (CI tighter).
  MaintenanceLimits get effectiveLimits =>
      mode == MaintenanceMode.ci ? MaintenanceLimits.ci : limits;
}

/// Deterministic maintenance controller (not an unrestricted coding agent).
class MaintenanceController {
  /// Creates a controller.
  MaintenanceController({
    MaintenanceHistory? history,
  }) : history = history ?? MaintenanceHistory();

  /// History store.
  final MaintenanceHistory history;

  /// Build a priority-ordered plan from subsystem inputs.
  MaintenancePlan plan({
    HealthReport? health,
    List<Diagnostic> security = const [],
    List<Diagnostic> source = const [],
    List<Diagnostic> drift = const [],
    bool pubdoctorHealthy = true,
    List<String> sdkWarnings = const [],
  }) {
    final actions = <MaintenanceAction>[];
    final counts = <String, int>{
      'dependencyHealth': health?.diagnostics.length ?? 0,
      'sourceIntegrity': source.length,
      'security': security.length,
      'drift': drift.length,
      'sdk': sdkWarnings.length,
    };

    if (!pubdoctorHealthy) {
      actions.add(
        const MaintenanceAction(
          id: 'heal-cache',
          description: 'Repair stale metadata cache / PubDoctor internal state',
          priority: MaintenancePriority.internalCorruption,
          safe: true,
          category: 'PubDoctor state',
        ),
      );
    }

    for (final d in security) {
      actions.add(
        MaintenanceAction(
          id: 'sec-${d.code}-${d.package ?? 'x'}',
          description: d.title,
          priority: MaintenancePriority.securityIntegrity,
          safe: false,
          category: 'Security',
          relatedDiagnostic: d.code,
        ),
      );
    }

    for (final d in health?.diagnostics ?? const <Diagnostic>[]) {
      final priority = d.code.startsWith('PD100')
          ? MaintenancePriority.dependencyResolution
          : MaintenancePriority.upgradeHealth;
      actions.add(
        MaintenanceAction(
          id: 'dep-${d.code}-${d.package ?? actions.length}',
          description: d.message,
          priority: priority,
          safe: d.severity.index <= DiagnosticSeverity.warning.index,
          category: 'Dependency health',
          relatedDiagnostic: d.code,
        ),
      );
    }

    for (final d in source) {
      actions.add(
        MaintenanceAction(
          id: 'src-${d.code}-${d.package ?? actions.length}',
          description: d.message,
          priority: MaintenancePriority.sourceCompilation,
          safe: true,
          category: 'Source integrity',
          relatedDiagnostic: d.code,
        ),
      );
    }

    for (final w in sdkWarnings) {
      actions.add(
        MaintenanceAction(
          id: 'sdk-${w.hashCode}',
          description: w,
          priority: MaintenancePriority.sdkCompatibility,
          safe: true,
          category: 'SDK compatibility',
        ),
      );
    }

    for (final d in drift) {
      actions.add(
        MaintenanceAction(
          id: 'drift-${d.code}',
          description: d.message,
          priority: MaintenancePriority.cleanup,
          safe: true,
          category: 'Drift',
          relatedDiagnostic: d.code,
        ),
      );
    }

    actions.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // Drop anything that violates safe autonomy.
    final filtered = [
      for (final a in actions)
        if (!SafeAutonomyContract.violates(a.description)) a,
    ];

    final summary = <String, String>{
      'Dependency health': _countLabel(counts['dependencyHealth'] ?? 0),
      'Source integrity': _countLabel(counts['sourceIntegrity'] ?? 0),
      'PubDoctor state': pubdoctorHealthy ? 'healthy' : 'needs attention',
      'Security': _countLabel(counts['security'] ?? 0, healthyWord: 'healthy'),
      'SDK compatibility': _countLabel(counts['sdk'] ?? 0, unit: 'warning'),
      'Drift': _countLabel(counts['drift'] ?? 0, healthyWord: 'none'),
    };

    return MaintenancePlan(
      actions: filtered,
      summary: summary,
      counts: counts,
    );
  }

  /// Run a maintenance cycle under [policy].
  MaintenanceResult run({
    required MaintenancePolicy policy,
    required MaintenancePlan plan,
    Set<String> currentDiagnosticCodes = const {},
  }) {
    final cycle = MaintenanceCycle(
      id: 'M-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      startedAt: DateTime.now().toUtc(),
      limits: policy.effectiveLimits,
    );

    final applied = <String>[];
    final skipped = <String>[];
    final historyEntries = <Map<String, Object?>>[];
    final compensating = <Map<String, Object?>>[];

    if (policy.repairHistory) {
      final regs = history.findRegressions(
        currentDiagnosticCodes: currentDiagnosticCodes,
      );
      for (final r in regs) {
        historyEntries.add(r);
        if (r['rollbackSafe'] != true) {
          compensating.add(history.compensatingTransaction(r));
        }
      }
    }

    if (policy.mode == MaintenanceMode.audit ||
        policy.mode == MaintenanceMode.ci && applied.isEmpty) {
      // audit / default ci plan-only path
    }

    final mutate = policy.mode == MaintenanceMode.apply ||
        policy.mode == MaintenanceMode.safe;

    for (final action in plan.actions) {
      final limit = cycle.limitReached();
      if (limit != null) {
        return MaintenanceResult(
          mode: policy.mode,
          plan: plan,
          applied: applied,
          skipped: [
            ...skipped,
            ...plan.actions
                .skip(applied.length + skipped.length)
                .map((a) => a.id)
          ],
          stoppedReason: 'Limit reached: $limit — manual review required',
          historyEntries: historyEntries,
          compensating: compensating,
        );
      }

      if (!mutate) {
        skipped.add(action.id);
        continue;
      }
      if (policy.mode == MaintenanceMode.safe && !action.safe) {
        skipped.add(action.id);
        continue;
      }
      if (SafeAutonomyContract.violates(action.description)) {
        skipped.add(action.id);
        continue;
      }

      // Apply is recorded as planned application — actual file mutation remains
      // delegated to RepairEngine / HealingEngine with verification.
      applied.add(action.id);
      cycle.actions++;
      final entry = {
        'id': 'R-${cycle.id}-${action.id}',
        'actionId': action.id,
        'description': action.description,
        'at': DateTime.now().toUtc().toIso8601String(),
        'rollbackSafe': action.safe,
        'introducedDiagnostics': <String>[],
      };
      history.append(entry);
      historyEntries.add(entry);
    }

    final stopped = !mutate
        ? 'No changes applied.'
        : applied.isEmpty
            ? 'No safe actions to apply.'
            : 'Completed within limits.';

    return MaintenanceResult(
      mode: policy.mode,
      plan: plan,
      applied: applied,
      skipped: skipped,
      stoppedReason: stopped,
      historyEntries: historyEntries,
      compensating: compensating,
    );
  }

  static String _countLabel(
    int n, {
    String healthyWord = 'healthy',
    String unit = 'issue',
  }) {
    if (n <= 0) return healthyWord;
    final u = n == 1 ? unit : '${unit}s';
    return '$n $u';
  }
}
