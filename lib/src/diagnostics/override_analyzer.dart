import 'package:pub_semver/pub_semver.dart';

import '../constraints/constraint_analyzer.dart';
import '../models/dependency_spec.dart';
import '../models/diagnostics.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';

/// Analyzes `dependency_overrides` without modifying pubspec.yaml.
class OverrideAnalyzer {
  /// Creates an override analyzer.
  OverrideAnalyzer(this.workspace, {ConstraintAnalyzer? constraintAnalyzer})
      : _constraints = constraintAnalyzer ?? ConstraintAnalyzer(workspace);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  final ConstraintAnalyzer _constraints;

  /// Analyze all overrides.
  List<OverrideAnalysis> analyze() {
    final overrides = workspace.pubspec.dependencyOverrides;
    if (overrides.isEmpty) return const [];

    final conflicts = _constraints.analyze(includeNarrow: false);
    final emptyIntersection = <String>{
      for (final c in conflicts)
        if (c.intersection.isEmpty) c.package,
    };

    final requirements = _constraints.collectRequirements();
    final results = <OverrideAnalysis>[];

    for (final spec in overrides) {
      final locked = workspace.lockfile?[spec.name];
      final reqs = requirements[spec.name] ?? const [];

      if (workspace.lockfile == null) {
        results.add(
          OverrideAnalysis(
            package: spec.name,
            classification: OverrideClassification.unknown,
            explanation:
                'No pubspec.lock found — cannot determine whether the override '
                'for "${spec.name}" is still necessary.',
            declaredConstraint: _describe(spec),
          ),
        );
        continue;
      }

      if (emptyIntersection.contains(spec.name)) {
        results.add(
          OverrideAnalysis(
            package: spec.name,
            classification: OverrideClassification.necessary,
            explanation:
                'Dependents declare incompatible constraints on "${spec.name}". '
                'The override is likely still required until those constraints '
                'are aligned.',
            declaredConstraint: _describe(spec),
            resolvedVersion: locked?.version,
          ),
        );
        continue;
      }

      if (reqs.isEmpty) {
        results.add(
          OverrideAnalysis(
            package: spec.name,
            classification: OverrideClassification.possiblyUnnecessary,
            explanation:
                'No graph constraints were found for "${spec.name}". The '
                'override may be leftover, but verify with '
                '`dart pub get` after removal.',
            declaredConstraint: _describe(spec),
            resolvedVersion: locked?.version,
            wouldResolveWithout: 'unknown (no constraint edges)',
          ),
        );
        continue;
      }

      final intersection =
          reqs.map((r) => r.constraint).fold<VersionConstraint>(
                VersionConstraint.any,
                (a, b) => a.intersect(b),
              );

      final unsafe = _looksUnsafe(spec, locked?.version, intersection);
      if (unsafe != null) {
        results.add(unsafe);
        continue;
      }

      if (locked != null && intersection.allows(locked.version)) {
        results.add(
          OverrideAnalysis(
            package: spec.name,
            classification: OverrideClassification.possiblyUnnecessary,
            explanation:
                'Resolved ${spec.name} ${locked.version} already satisfies '
                'the intersection of dependents ($intersection). The override '
                'may be removable — confirm with a clean resolve.',
            declaredConstraint: _describe(spec),
            resolvedVersion: locked.version,
            wouldResolveWithout: intersection.toString(),
          ),
        );
        continue;
      }

      results.add(
        OverrideAnalysis(
          package: spec.name,
          classification: OverrideClassification.unknown,
          explanation:
              'Could not conclusively classify the override for "${spec.name}". '
              'Inspect constraints manually or test removal carefully.',
          declaredConstraint: _describe(spec),
          resolvedVersion: locked?.version,
        ),
      );
    }

    return results;
  }

  /// Diagnostics for override findings.
  List<Diagnostic> toDiagnostics(List<OverrideAnalysis> analyses) {
    return [
      for (final a in analyses)
        Diagnostic(
          code: switch (a.classification) {
            OverrideClassification.necessary =>
              DiagnosticCodes.necessaryOverride,
            OverrideClassification.possiblyUnnecessary =>
              DiagnosticCodes.unnecessaryOverride,
            OverrideClassification.unsafe => DiagnosticCodes.unsafeOverride,
            OverrideClassification.unknown => DiagnosticCodes.unknownOverride,
          },
          title: 'Override: ${a.classification.name}',
          message: a.explanation,
          severity: switch (a.classification) {
            OverrideClassification.unsafe => DiagnosticSeverity.warning,
            OverrideClassification.possiblyUnnecessary =>
              DiagnosticSeverity.info,
            OverrideClassification.necessary => DiagnosticSeverity.info,
            OverrideClassification.unknown => DiagnosticSeverity.info,
          },
          package: a.package,
          evidence: [
            if (a.declaredConstraint != null)
              'Override: ${a.declaredConstraint}',
            if (a.resolvedVersion != null) 'Resolved: ${a.resolvedVersion}',
            if (a.wouldResolveWithout != null)
              'Without override (estimate): ${a.wouldResolveWithout}',
          ],
          remediation: switch (a.classification) {
            OverrideClassification.possiblyUnnecessary =>
              'Try removing the override and run `dart pub get`. '
                  'Optional check: `pubdoctor overrides --test ${a.package}`.',
            OverrideClassification.unsafe =>
              'Review whether forcing this version hides incompatibilities.',
            OverrideClassification.necessary =>
              'Align upstream constraints before removing this override.',
            OverrideClassification.unknown =>
              'Gather more graph/constraint data (ensure pubspec.lock exists).',
          },
        ),
    ];
  }

  OverrideAnalysis? _looksUnsafe(
    DependencySpec spec,
    Version? resolved,
    VersionConstraint intersection,
  ) {
    final constraint = spec.constraint;
    if (constraint is Version && !intersection.allows(constraint)) {
      return OverrideAnalysis(
        package: spec.name,
        classification: OverrideClassification.unsafe,
        explanation:
            'Override pins ${spec.name} to $constraint, which is outside the '
            'dependents\' intersection ($intersection). This can mask '
            'incompatibilities.',
        declaredConstraint: _describe(spec),
        resolvedVersion: resolved,
        wouldResolveWithout: intersection.toString(),
      );
    }
    return null;
  }

  String _describe(DependencySpec spec) {
    switch (spec.source) {
      case DependencySource.path:
        return 'path: ${spec.path}';
      case DependencySource.git:
        return 'git: ${spec.gitUrl}${spec.gitRef != null ? '#${spec.gitRef}' : ''}';
      case DependencySource.sdk:
        return 'sdk: ${spec.sdk}';
      case DependencySource.hosted:
        return '${spec.name} ${spec.constraint}';
    }
  }
}
