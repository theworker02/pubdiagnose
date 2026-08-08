import 'healing_policy.dart';

/// A detected internal / recoverable issue.
class HealingIssue {
  /// Creates an issue.
  const HealingIssue({
    required this.id,
    required this.code,
    required this.title,
    required this.message,
    required this.tier,
    this.evidence = const [],
    this.subsystem,
  });

  /// Stable issue id within a session.
  final String id;

  /// Diagnostic-style code (e.g. PDH201).
  final String code;

  /// Title.
  final String title;

  /// Message.
  final String message;

  /// Safety tier.
  final SafetyTier tier;

  /// Evidence.
  final List<String> evidence;

  /// Subsystem name.
  final String? subsystem;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'message': message,
        'tier': tier.name,
        if (subsystem != null) 'subsystem': subsystem,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}

/// A single healing action.
class HealingAction {
  /// Creates an action.
  const HealingAction({
    required this.id,
    required this.description,
    required this.risk,
    required this.confidence,
    this.filesAffected = const [],
    this.modifiesProjectSource = false,
  });

  /// Action id.
  final String id;

  /// Description.
  final String description;

  /// Risk.
  final HealingRisk risk;

  /// Confidence.
  final HealingConfidence confidence;

  /// Files that may change.
  final List<String> filesAffected;

  /// Whether app source would be touched (must be false for --safe).
  final bool modifiesProjectSource;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
        'risk': risk.name,
        'confidence': confidence.name,
        'filesAffected': filesAffected,
        'modifiesProjectSource': modifiesProjectSource,
      };
}

/// Planned healing steps for one or more issues.
class HealingPlan {
  /// Creates a plan.
  const HealingPlan({
    required this.id,
    required this.actions,
    required this.issues,
    this.summary,
  });

  /// Plan id.
  final String id;

  /// Actions.
  final List<HealingAction> actions;

  /// Issues addressed.
  final List<HealingIssue> issues;

  /// Summary.
  final String? summary;

  /// Whether all actions qualify for `--safe` auto heal.
  bool get isSafeAutoEligible => actions.every(
        (a) =>
            !a.modifiesProjectSource &&
            a.risk == HealingRisk.low &&
            (a.confidence == HealingConfidence.certain ||
                a.confidence == HealingConfidence.high),
      );

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'summary': summary,
        'safeAutoEligible': isSafeAutoEligible,
        'issues': [for (final i in issues) i.toJson()],
        'actions': [for (final a in actions) a.toJson()],
      };
}

/// Result of applying a healing plan.
class HealingResult {
  /// Creates a result.
  const HealingResult({
    required this.planId,
    required this.applied,
    required this.rolledBack,
    required this.success,
    this.actions = const [],
    this.beforeHealth = const {},
    this.afterHealth = const {},
    this.message,
  });

  /// Plan id.
  final String planId;

  /// Whether changes were applied.
  final bool applied;

  /// Whether rollback occurred.
  final bool rolledBack;

  /// Overall success after verification.
  final bool success;

  /// Action log lines.
  final List<String> actions;

  /// Health before.
  final Map<String, Object?> beforeHealth;

  /// Health after.
  final Map<String, Object?> afterHealth;

  /// Message.
  final String? message;

  /// JSON.
  Map<String, Object?> toJson() => {
        'planId': planId,
        'applied': applied,
        'rolledBack': rolledBack,
        'success': success,
        'actions': actions,
        'beforeHealth': beforeHealth,
        'afterHealth': afterHealth,
        if (message != null) 'message': message,
      };
}
