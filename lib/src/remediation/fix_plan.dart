import '../models/diagnostics.dart';
import '../models/recommendations.dart';

/// Risk level for a fix plan.
enum RiskLevel {
  /// Safe under semver assumptions / removals of unused overrides.
  safe,

  /// May include potentially breaking edits.
  moderate,

  /// Explicitly breaking or high-uncertainty changes.
  high,
}

/// Kind of pubspec mutation.
enum FixChangeKind {
  /// Remove a dependency_overrides entry.
  removeOverride,

  /// Remove a dependency from dependencies/dev_dependencies.
  removeDependency,

  /// Add a dependency declaration.
  addDependency,

  /// Move between dependency sections.
  moveDependency,

  /// Adjust a version constraint string.
  adjustConstraint,
}

/// A single proposed pubspec change with full audit trail.
class FixChange {
  /// Creates a fix change.
  const FixChange({
    required this.kind,
    required this.package,
    required this.what,
    required this.why,
    required this.evidence,
    required this.expectedResult,
    required this.risk,
    this.section,
    this.from,
    this.to,
    this.resolvesCodes = const [],
  });

  /// Mutation kind.
  final FixChangeKind kind;

  /// Affected package.
  final String package;

  /// WHAT will change.
  final String what;

  /// WHY.
  final String why;

  /// Evidence strings.
  final List<String> evidence;

  /// EXPECTED RESULT.
  final String expectedResult;

  /// Risk.
  final ChangeRisk risk;

  /// Target section when relevant.
  final String? section;

  /// Current value.
  final String? from;

  /// Proposed value.
  final String? to;

  /// Diagnostic codes this change aims to resolve.
  final List<String> resolvesCodes;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'package': package,
        'what': what,
        'why': why,
        'evidence': evidence,
        'expectedResult': expectedResult,
        'risk': risk.name,
        if (section != null) 'section': section,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'resolvesCodes': resolvesCodes,
      };
}

/// A complete remediation plan (no mutation until applied).
class FixPlan {
  /// Creates a fix plan.
  const FixPlan({
    required this.changes,
    required this.resolvedDiagnostics,
    required this.remainingDiagnostics,
    required this.risk,
    this.notes = const [],
  });

  /// Proposed changes.
  final List<FixChange> changes;

  /// Diagnostics expected to be resolved.
  final List<Diagnostic> resolvedDiagnostics;

  /// Diagnostics expected to remain.
  final List<Diagnostic> remainingDiagnostics;

  /// Overall risk.
  final RiskLevel risk;

  /// Extra notes.
  final List<String> notes;

  /// Whether the plan is empty.
  bool get isEmpty => changes.isEmpty;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'risk': risk.name,
        'changes': [for (final c in changes) c.toJson()],
        'resolvedDiagnostics': [
          for (final d in resolvedDiagnostics) d.toJson(),
        ],
        'remainingDiagnostics': [
          for (final d in remainingDiagnostics) d.toJson(),
        ],
        'notes': notes,
      };
}

/// Result of applying a [FixPlan].
class FixApplyResult {
  /// Creates a result.
  const FixApplyResult({
    required this.applied,
    required this.plan,
    this.rolledBack = false,
    this.message,
    this.wrotePath,
  });

  /// Whether changes were written.
  final bool applied;

  /// Plan that was considered/applied.
  final FixPlan plan;

  /// Whether a rollback occurred.
  final bool rolledBack;

  /// Human message.
  final String? message;

  /// Path written.
  final String? wrotePath;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'applied': applied,
        'rolledBack': rolledBack,
        if (message != null) 'message': message,
        if (wrotePath != null) 'wrotePath': wrotePath,
        'plan': plan.toJson(),
      };
}
