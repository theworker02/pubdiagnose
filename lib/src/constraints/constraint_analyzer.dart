import 'package:pub_semver/pub_semver.dart';

import '../graph/dependency_graph.dart';
import '../models/constraints.dart';
import '../models/diagnostics.dart';
import '../models/graph_models.dart';
import '../workspace/workspace_loader.dart';

/// Analyzes version constraints across the dependency graph.
class ConstraintAnalyzer {
  /// Creates a constraint analyzer for [workspace].
  ConstraintAnalyzer(this.workspace);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  DependencyGraph get _graph => workspace.graph;

  /// Collects all known requirements for each package.
  Map<String, List<ConstraintRequirement>> collectRequirements() {
    final result = <String, List<ConstraintRequirement>>{};

    for (final edge in _graph.edges) {
      if (edge.constraint == null) continue;
      if (edge.to == _graph.rootName) continue;

      final path = _graph.shortestPathTo(edge.from) ??
          DependencyPath([_graph.rootName, edge.from]);

      final req = ConstraintRequirement(
        package: edge.to,
        requiredBy: edge.from,
        constraint: edge.constraint!,
        path: path,
      );
      result.putIfAbsent(edge.to, () => []).add(req);
    }

    return result;
  }

  /// Finds conflicts and suspicious narrow intersections.
  List<DependencyConflict> analyze({
    bool includeNarrow = true,
  }) {
    final requirements = collectRequirements();
    final conflicts = <DependencyConflict>[];

    for (final entry in requirements.entries) {
      final package = entry.key;
      final reqs = entry.value;
      if (reqs.isEmpty) continue;

      final intersection = _intersectAll(reqs.map((r) => r.constraint));
      if (intersection.isEmpty) {
        final minimal = _minimalIncompatible(reqs);
        conflicts.add(
          DependencyConflict(
            package: package,
            requirements: reqs,
            intersection: intersection,
            severity: ConflictSeverity.error,
            minimalIncompatible: minimal,
            explanation:
                'Constraints on "$package" have an empty intersection. '
                'A compatible version cannot satisfy all dependents without '
                'overrides or constraint changes.',
          ),
        );
        continue;
      }

      if (includeNarrow && reqs.length >= 2 && _isNarrow(intersection)) {
        conflicts.add(
          DependencyConflict(
            package: package,
            requirements: reqs,
            intersection: intersection,
            severity: ConflictSeverity.warning,
            explanation:
                'Constraints on "$package" intersect only at "$intersection", '
                'which is fragile — small changes may break resolution.',
          ),
        );
      }
    }

    conflicts.sort((a, b) {
      final severity = b.severity.index.compareTo(a.severity.index);
      if (severity != 0) return severity;
      return a.package.compareTo(b.package);
    });
    return conflicts;
  }

  /// Converts conflicts into diagnostics.
  List<Diagnostic> toDiagnostics(List<DependencyConflict> conflicts) {
    return [
      for (final c in conflicts)
        Diagnostic(
          code: c.severity == ConflictSeverity.error
              ? DiagnosticCodes.dependencyConflict
              : DiagnosticCodes.narrowConstraint,
          title: c.severity == ConflictSeverity.error
              ? 'Dependency conflict'
              : 'Narrow constraint intersection',
          message:
              c.explanation ?? 'Constraint issue detected for "${c.package}".',
          severity: c.severity == ConflictSeverity.error
              ? DiagnosticSeverity.error
              : DiagnosticSeverity.warning,
          package: c.package,
          evidence: [
            for (final r in c.requirements)
              '${r.requiredBy} requires ${r.package} ${r.constraint} '
                  '(via ${r.path.display})',
            'Intersection: ${c.intersection}',
          ],
          paths: [
            for (final r in (c.minimalIncompatible.isNotEmpty
                    ? c.minimalIncompatible
                    : c.requirements)
                .take(5))
              r.path,
          ],
          remediation: c.severity == ConflictSeverity.error
              ? 'Loosen or align constraints on "${c.package}", or temporarily '
                  'use dependency_overrides (then re-check with '
                  '`pubdoctor overrides`).'
              : 'Consider aligning dependents on a shared constraint range.',
        ),
    ];
  }

  VersionConstraint _intersectAll(Iterable<VersionConstraint> constraints) {
    VersionConstraint result = VersionConstraint.any;
    for (final c in constraints) {
      result = result.intersect(c);
      if (result.isEmpty) return result;
    }
    return result;
  }

  /// Finds a small subset of requirements that already conflict.
  List<ConstraintRequirement> _minimalIncompatible(
    List<ConstraintRequirement> reqs,
  ) {
    // Prefer a pair that conflicts; otherwise grow a set until empty.
    for (var i = 0; i < reqs.length; i++) {
      for (var j = i + 1; j < reqs.length; j++) {
        final intersection = reqs[i].constraint.intersect(reqs[j].constraint);
        if (intersection.isEmpty) {
          return [reqs[i], reqs[j]];
        }
      }
    }

    final selected = <ConstraintRequirement>[];
    VersionConstraint current = VersionConstraint.any;
    for (final r in reqs) {
      selected.add(r);
      current = current.intersect(r.constraint);
      if (current.isEmpty) return selected;
    }
    return selected;
  }

  bool _isNarrow(VersionConstraint constraint) {
    if (constraint.isEmpty) return false;
    if (constraint is Version) return true;
    if (constraint is VersionRange) {
      final min = constraint.min;
      final max = constraint.max;
      if (min != null && max != null) {
        // Single version range like >=1.2.3 <1.2.4
        if (min.major == max.major &&
            min.minor == max.minor &&
            (max.patch - min.patch).abs() <= 1 &&
            !constraint.includeMax) {
          return true;
        }
        // Extremely tight: only one possible stable version often.
        if (min == max) return true;
      }
    }
    // Compatible constraint with very high minimum relative to max is narrow
    // when it allows only pre-releases — skip; treat exact pins as narrow.
    final text = constraint.toString();
    if (RegExp(r'^[=]?(\d+\.){2}\d+').hasMatch(text) && !text.contains(' ')) {
      return true;
    }
    return false;
  }
}
