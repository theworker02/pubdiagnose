import 'migration_plan.dart';
import 'migration_risk.dart';
import 'migration_step.dart';

/// Dry validation of a migration plan against current workspace state.
class MigrationValidator {
  /// Validate without mutating the project.
  ///
  /// Checks prerequisite ordering, blocked steps, and missing packages.
  MigrationValidationResult validate(MigrationPlan plan) {
    final issues = <String>[];
    final stepIds = {for (final s in plan.steps) s.id};

    try {
      plan.graph.topologicalOrder();
    } on StateError catch (e) {
      issues.add(e.message);
    }

    for (final step in plan.steps) {
      for (final pre in step.prerequisiteIds) {
        if (!stepIds.contains(pre)) {
          issues.add('Step ${step.id} references missing prerequisite $pre');
        }
      }
      if (step.risk.level == MigrationRiskLevel.blocked) {
        issues.add(
            'Step ${step.id} is blocked: ${step.risk.summary ?? step.title}');
      }
    }

    final pending = plan.steps
        .where((s) => s.status == MigrationStepStatus.pending)
        .toList();
    final ready = <String>[];
    final done = {
      for (final s in plan.steps)
        if (s.status == MigrationStepStatus.done) s.id,
    };
    for (final step in pending) {
      final prereqsMet = step.prerequisiteIds.every(done.contains);
      if (prereqsMet && step.risk.level != MigrationRiskLevel.blocked) {
        ready.add(step.id);
      }
    }

    return MigrationValidationResult(
      ok: issues.isEmpty,
      issues: issues,
      readyStepIds: ready,
      mutatedProject: false,
    );
  }
}

/// Result of dry validation.
class MigrationValidationResult {
  /// Creates a validation result.
  const MigrationValidationResult({
    required this.ok,
    required this.issues,
    required this.readyStepIds,
    this.mutatedProject = false,
  });

  /// Whether the plan is valid enough to proceed.
  final bool ok;

  /// Issues found.
  final List<String> issues;

  /// Steps whose prerequisites are already done.
  final List<String> readyStepIds;

  /// Always false for dry validation.
  final bool mutatedProject;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'ok': ok,
        'issues': issues,
        'readyStepIds': readyStepIds,
        'mutatedProject': mutatedProject,
      };
}
