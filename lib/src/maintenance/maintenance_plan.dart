/// Priority ordering for maintenance actions (lower = first).
enum MaintenancePriority {
  /// Internal PubDoctor / cache corruption.
  internalCorruption,

  /// Security / integrity.
  securityIntegrity,

  /// Dependency resolution.
  dependencyResolution,

  /// Source compilation.
  sourceCompilation,

  /// Tests.
  tests,

  /// SDK compatibility.
  sdkCompatibility,

  /// Upgrade health.
  upgradeHealth,

  /// Cleanup.
  cleanup,
}

/// Safe autonomy contract — actions PubDoctor must never take automatically.
abstract final class SafeAutonomyContract {
  /// Forbidden automatic behaviors.
  static const forbidden = [
    'invent application behavior',
    'delete source files without explicit approval',
    'rewrite broad areas of code for style',
    'downgrade security policy silently',
    'suppress diagnostics just to produce a clean report',
    'alter tests simply to make them pass',
    'hide unresolved issues',
    'loop indefinitely',
  ];

  /// Whether [description] appears to violate the contract (heuristic).
  static bool violates(String description) {
    final d = description.toLowerCase();
    if (d.contains('delete source') || d.contains('delete file')) return true;
    if (d.contains('suppress diagnostic')) return true;
    if (d.contains('edit test') || d.contains('alter test')) return true;
    if (d.contains('weaken security') || d.contains('downgrade security')) {
      return true;
    }
    return false;
  }
}

/// Loop / blast-radius limits for a maintenance cycle.
class MaintenanceLimits {
  /// Creates limits.
  const MaintenanceLimits({
    this.maxActions = 20,
    this.maxRepairIterations = 3,
    this.maxElapsed = const Duration(minutes: 10),
    this.maxChangedFiles = 40,
    this.maxChangedLines = 2000,
  });

  /// Defaults.
  static const defaults = MaintenanceLimits();

  /// CI-oriented tighter limits.
  static const ci = MaintenanceLimits(
    maxActions: 10,
    maxRepairIterations: 2,
    maxElapsed: Duration(minutes: 5),
    maxChangedFiles: 20,
    maxChangedLines: 1000,
  );

  /// Max actions per cycle.
  final int maxActions;

  /// Max repair iterations.
  final int maxRepairIterations;

  /// Max elapsed time.
  final Duration maxElapsed;

  /// Max changed files.
  final int maxChangedFiles;

  /// Max changed lines.
  final int maxChangedLines;

  /// JSON.
  Map<String, Object?> toJson() => {
        'maxActions': maxActions,
        'maxRepairIterations': maxRepairIterations,
        'maxElapsedMs': maxElapsed.inMilliseconds,
        'maxChangedFiles': maxChangedFiles,
        'maxChangedLines': maxChangedLines,
      };
}

/// Maintenance policy / mode.
enum MaintenanceMode {
  /// Audit only — no mutations.
  audit,

  /// Only deterministic low-risk changes.
  safe,

  /// Apply approved plan under repair safeguards.
  apply,

  /// Machine-oriented non-interactive.
  ci,
}

/// A single proposed maintenance action.
class MaintenanceAction {
  /// Creates an action.
  const MaintenanceAction({
    required this.id,
    required this.description,
    required this.priority,
    this.safe = true,
    this.category = 'general',
    this.relatedDiagnostic,
  });

  /// Id.
  final String id;

  /// Description.
  final String description;

  /// Priority.
  final MaintenancePriority priority;

  /// Whether safe for `--safe`.
  final bool safe;

  /// Category label.
  final String category;

  /// Related diagnostic code.
  final String? relatedDiagnostic;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
        'priority': priority.name,
        'safe': safe,
        'category': category,
        if (relatedDiagnostic != null) 'relatedDiagnostic': relatedDiagnostic,
      };
}

/// Ordered maintenance plan.
class MaintenancePlan {
  /// Creates a plan.
  const MaintenancePlan({
    required this.actions,
    required this.summary,
    this.counts = const {},
  });

  /// Actions in priority order.
  final List<MaintenanceAction> actions;

  /// Human summary sections.
  final Map<String, String> summary;

  /// Issue counts by area.
  final Map<String, int> counts;

  /// JSON.
  Map<String, Object?> toJson() => {
        'summary': summary,
        'counts': counts,
        'actions': [for (final a in actions) a.toJson()],
      };
}

/// Result of a maintenance cycle.
class MaintenanceResult {
  /// Creates a result.
  const MaintenanceResult({
    required this.mode,
    required this.plan,
    required this.applied,
    required this.skipped,
    required this.stoppedReason,
    this.historyEntries = const [],
    this.compensating = const [],
  });

  /// Mode.
  final MaintenanceMode mode;

  /// Plan.
  final MaintenancePlan plan;

  /// Applied action ids.
  final List<String> applied;

  /// Skipped action ids.
  final List<String> skipped;

  /// Why the loop stopped.
  final String stoppedReason;

  /// History entries written.
  final List<Map<String, Object?>> historyEntries;

  /// Compensating transactions proposed.
  final List<Map<String, Object?>> compensating;

  /// JSON.
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'plan': plan.toJson(),
        'applied': applied,
        'skipped': skipped,
        'stoppedReason': stoppedReason,
        'historyEntries': historyEntries,
        'compensating': compensating,
        'autonomyContract': SafeAutonomyContract.forbidden,
      };
}

/// One maintenance cycle metadata.
class MaintenanceCycle {
  /// Creates a cycle.
  MaintenanceCycle({
    required this.id,
    required this.startedAt,
    this.limits = MaintenanceLimits.defaults,
  });

  /// Cycle id.
  final String id;

  /// Start time.
  final DateTime startedAt;

  /// Limits.
  final MaintenanceLimits limits;

  /// Actions executed so far.
  int actions = 0;

  /// Files changed.
  int changedFiles = 0;

  /// Lines changed.
  int changedLines = 0;

  /// Whether limits are exhausted.
  String? limitReached() {
    if (actions >= limits.maxActions) return 'maximum actions';
    if (changedFiles >= limits.maxChangedFiles) return 'maximum changed files';
    if (changedLines >= limits.maxChangedLines) return 'maximum changed lines';
    if (DateTime.now().toUtc().difference(startedAt) >= limits.maxElapsed) {
      return 'maximum elapsed time';
    }
    return null;
  }
}

/// Durable maintenance history (for --repair-history).
class MaintenanceHistory {
  /// Creates history store in memory (tests) or via callbacks.
  MaintenanceHistory({List<Map<String, Object?>>? seed})
      : _entries = [...?seed];

  final List<Map<String, Object?>> _entries;

  /// All entries newest last.
  List<Map<String, Object?>> get entries => List.unmodifiable(_entries);

  /// Append.
  void append(Map<String, Object?> entry) => _entries.add(entry);

  /// Find prior PubDoctor transactions that may have caused regressions.
  List<Map<String, Object?>> findRegressions({
    required Set<String> currentDiagnosticCodes,
  }) {
    final out = <Map<String, Object?>>[];
    for (final e in _entries) {
      final introduced = (e['introducedDiagnostics'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          {};
      final hit = introduced.intersection(currentDiagnosticCodes);
      if (hit.isNotEmpty) {
        out.add({
          ...e,
          'regressionDetected': hit.toList(),
          'action': e['rollbackSafe'] == true
              ? 'rollback available'
              : 'compensating repair available',
        });
      }
    }
    return out;
  }

  /// Propose compensating transaction when rollback is unsafe.
  Map<String, Object?> compensatingTransaction(Map<String, Object?> prior) {
    return {
      'kind': 'compensating',
      'priorTransaction': prior['id'],
      'reason':
          'Original rollback may be unsafe because subsequent developer edits '
              'conflict with restoring prior file snapshots.',
      'steps': [
        'diff current tree against post-repair state',
        'apply minimal inverse of PubDoctor mutation only',
        're-verify postconditions',
      ],
      'safe': true,
    };
  }
}
