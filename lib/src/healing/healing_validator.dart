import 'healing_context.dart';
import 'healing_issue.dart';
import 'healing_policy.dart';

/// Provider of healing detect/plan/apply for a subsystem.
abstract interface class HealingProvider {
  /// Provider id.
  String get id;

  /// Detect issues.
  Future<List<HealingIssue>> detect(HealingContext context);

  /// Plan repair for [issue], or null if unsupported.
  Future<HealingPlan?> plan(HealingIssue issue, HealingContext context);

  /// Apply [plan].
  Future<HealingResult> apply(HealingPlan plan, HealingContext context);
}

/// Validates healing outcomes by re-running health probes.
class HealingValidator {
  /// Compare issue counts — success if after <= before for recoverable issues.
  bool improved({
    required int beforeIssues,
    required int afterIssues,
  }) =>
      afterIssues <= beforeIssues;

  /// Whether an action may run under `--safe`.
  bool allowsSafe(HealingAction action) =>
      !action.modifiesProjectSource &&
      action.risk == HealingRisk.low &&
      (action.confidence == HealingConfidence.certain ||
          action.confidence == HealingConfidence.high);
}
