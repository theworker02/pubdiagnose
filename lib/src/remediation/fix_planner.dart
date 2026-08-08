import '../diagnostics/health_analyzer.dart';
import '../diagnostics/import_analyzer.dart';
import '../diagnostics/override_analyzer.dart';
import '../diagnostics/unused_analyzer.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';
import 'fix_plan.dart';

/// Builds a [FixPlan] without mutating files.
class FixPlanner {
  /// Creates a planner.
  FixPlanner(this.workspace, {HealthReport? report}) : _report = report;

  /// Workspace.
  final PubWorkspace workspace;

  final HealthReport? _report;

  /// Plan fixes. Optionally filter by [code] (e.g. PD1101) or [package].
  FixPlan plan({
    String? code,
    String? package,
    bool safeOnly = false,
  }) {
    final report = _report ??
        HealthAnalyzer(
          workspace: workspace,
          includeImportAnalysis: true,
          includeUnused: true,
        ).analyze();

    final changes = <FixChange>[];
    final resolved = <Diagnostic>[];

    final normalizedCode = code?.trim().toUpperCase();

    // Unnecessary overrides → remove override.
    final overrides = OverrideAnalyzer(workspace).analyze();
    for (final o in overrides) {
      if (o.classification != OverrideClassification.possiblyUnnecessary) {
        continue;
      }
      if (package != null && o.package != package) continue;
      if (normalizedCode != null &&
          normalizedCode != DiagnosticCodes.unnecessaryOverride &&
          normalizedCode != 'OVERRIDE' &&
          normalizedCode != 'OVERRIDES') {
        continue;
      }
      final change = FixChange(
        kind: FixChangeKind.removeOverride,
        package: o.package,
        what: 'Remove dependency_overrides entry for ${o.package}',
        why: o.explanation,
        evidence: [
          if (o.declaredConstraint != null) o.declaredConstraint!,
          if (o.resolvedVersion != null) 'resolved ${o.resolvedVersion}',
          if (o.wouldResolveWithout != null)
            'without override estimate: ${o.wouldResolveWithout}',
        ],
        expectedResult:
            'PD1101 for ${o.package} should clear after a successful '
            '`dart pub get`.',
        risk: ChangeRisk.unknownImpact,
        section: 'dependency_overrides',
        resolvesCodes: const [DiagnosticCodes.unnecessaryOverride],
      );
      if (safeOnly && change.risk != ChangeRisk.safe) {
        // Removals of possibly-unnecessary overrides are allowed under --safe
        // as unknownImpact but not potentiallyBreaking.
        if (change.risk == ChangeRisk.potentiallyBreaking) continue;
      }
      changes.add(change);
      resolved.addAll(
        report.diagnostics.where(
          (d) =>
              d.code == DiagnosticCodes.unnecessaryOverride &&
              d.package == o.package,
        ),
      );
    }

    // High-confidence unused deps → remove dependency.
    final unused = UnusedAnalyzer(workspace).analyze();
    for (final u in unused) {
      if (u.confidence != UnusedConfidence.high) continue;
      if (package != null && u.package != package) continue;
      if (normalizedCode != null &&
          normalizedCode != DiagnosticCodes.unusedDependency &&
          normalizedCode != 'UNUSED') {
        // Allow generic plans without code filter.
        if (code != null) continue;
      }
      final change = FixChange(
        kind: FixChangeKind.removeDependency,
        package: u.package,
        what: 'Remove ${u.package} from ${u.section}',
        why: u.reasons.join(' '),
        evidence: u.reasons,
        expectedResult:
            'PD1302 for ${u.package} should clear; `dart pub get` should succeed.',
        risk: ChangeRisk.safe,
        section: u.section,
        resolvesCodes: const [DiagnosticCodes.unusedDependency],
      );
      if (safeOnly && change.risk == ChangeRisk.potentiallyBreaking) continue;
      changes.add(change);
      resolved.addAll(
        report.diagnostics.where(
          (d) =>
              d.code == DiagnosticCodes.unusedDependency &&
              d.package == u.package,
        ),
      );
    }

    // Undeclared imports → add dependency.
    final imports = ImportAnalyzer(workspace).analyze();
    for (final i in imports) {
      if (package != null && i.package != package) continue;
      if (normalizedCode != null &&
          normalizedCode != DiagnosticCodes.directImportNotDeclared &&
          normalizedCode != 'IMPORTS' &&
          normalizedCode != 'IMPORT') {
        if (code != null) continue;
      }
      final section = i.isDevContext ? 'dev_dependencies' : 'dependencies';
      final change = FixChange(
        kind: FixChangeKind.addDependency,
        package: i.package,
        what: 'Add ${i.package}: any to $section',
        why: 'Direct package import without a matching pubspec declaration.',
        evidence: [
          for (final f in i.files.take(5)) 'import in $f',
          if (i.transitiveOnly) 'currently transitive-only / undeclared',
        ],
        expectedResult: 'PD1301 for ${i.package} should clear.',
        risk: ChangeRisk.safe,
        section: section,
        to: 'any',
        resolvesCodes: const [DiagnosticCodes.directImportNotDeclared],
      );
      if (safeOnly && change.risk == ChangeRisk.potentiallyBreaking) continue;
      changes.add(change);
      resolved.addAll(
        report.diagnostics.where(
          (d) =>
              d.code == DiagnosticCodes.directImportNotDeclared &&
              d.package == i.package,
        ),
      );
    }

    // Filter remaining.
    final resolvedKeys = {
      for (final d in resolved) '${d.code}|${d.package}',
    };
    final remaining = [
      for (final d in report.diagnostics)
        if (!resolvedKeys.contains('${d.code}|${d.package}')) d,
    ];

    final risk = _risk(changes);
    return FixPlan(
      changes: changes,
      resolvedDiagnostics: resolved,
      remainingDiagnostics: remaining,
      risk: risk,
      notes: [
        'This plan does not run `dart pub get`; validate after applying.',
        if (safeOnly) 'Filtered to --safe changes only.',
        'Breaking changes are never included under --safe.',
      ],
    );
  }

  RiskLevel _risk(List<FixChange> changes) {
    if (changes.any((c) => c.risk == ChangeRisk.potentiallyBreaking)) {
      return RiskLevel.high;
    }
    if (changes.any((c) => c.risk == ChangeRisk.unknownImpact)) {
      return RiskLevel.moderate;
    }
    return RiskLevel.safe;
  }
}
