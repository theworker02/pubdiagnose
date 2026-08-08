import 'package:pub_semver/pub_semver.dart';

import '../diagnostics/import_analyzer.dart';
import '../models/dependency_spec.dart';
import '../models/diagnostics.dart';
import '../workspace/monorepo_analyzer.dart';
import '../workspace/workspace_loader.dart';
import 'policy_parser.dart';
import 'policy_result.dart';
import 'policy_rule.dart';

/// Evaluates workspace governance policies.
class PolicyEngine {
  /// Creates a policy engine.
  PolicyEngine({
    required this.workspace,
    List<PolicyRule>? rules,
    this.sourcePath,
  }) : rules = rules ?? PolicyParser.defaults();

  /// Workspace.
  final PubWorkspace workspace;

  /// Rules to evaluate.
  final List<PolicyRule> rules;

  /// Config source.
  final String? sourcePath;

  /// List rules (for `policy list`).
  List<PolicyRule> listRules() => List.unmodifiable(rules);

  /// Explain a rule id.
  PolicyRule? explain(String id) {
    for (final r in rules) {
      if (r.id == id || r.kind.name == id) return r;
    }
    return null;
  }

  /// Check all enabled rules.
  Future<PolicyResult> check() async {
    final findings = <PolicyFinding>[];
    var evaluated = 0;
    for (final rule in rules) {
      if (!rule.enabled) continue;
      evaluated++;
      findings.addAll(await _evaluate(rule));
    }
    return PolicyResult(
      findings: findings,
      rulesEvaluated: evaluated,
      sourcePath: sourcePath,
    );
  }

  Future<List<PolicyFinding>> _evaluate(PolicyRule rule) async {
    return switch (rule.kind) {
      PolicyRuleKind.banOverrides => _banOverrides(rule),
      PolicyRuleKind.sdkMinimum => _sdkMinimum(rule),
      PolicyRuleKind.requireDirectDeclaration => _requireDirect(rule),
      PolicyRuleKind.forbiddenPackages => _forbidden(rule),
      PolicyRuleKind.versionRanges => _versionRanges(rule),
      PolicyRuleKind.requiredPackages => _required(rule),
      PolicyRuleKind.maxAge => _maxAge(rule),
      PolicyRuleKind.noExternalGitPath => _noExternalGitPath(rule),
      PolicyRuleKind.noWildcards => _noWildcards(rule),
      PolicyRuleKind.pinnedSdk => _pinnedSdk(rule),
      PolicyRuleKind.consistentWorkspaceVersions =>
        await _consistentWorkspace(rule),
    };
  }

  List<PolicyFinding> _banOverrides(PolicyRule rule) {
    final overs = workspace.pubspec.dependencyOverrides;
    if (overs.isEmpty) return const [];
    return [
      for (final o in overs)
        if (rule.scope.package == null || rule.scope.package == o.name)
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message:
                'dependency_overrides entry for "${o.name}" is banned by policy.',
            severity: DiagnosticSeverity.error,
            package: o.name,
            evidence: ['override present in pubspec.yaml'],
            remediation: 'Remove the override or adjust policy.',
          ),
    ];
  }

  List<PolicyFinding> _sdkMinimum(PolicyRule rule) {
    final raw = rule.params['version']?.toString();
    if (raw == null) return const [];
    Version min;
    try {
      min = Version.parse(raw.startsWith('^') || raw.startsWith('>')
          ? raw.replaceFirst(RegExp(r'^[\^>=< ]+'), '').split(' ').first
          : raw);
    } on Object {
      return [
        PolicyFinding(
          ruleId: rule.id,
          kind: rule.kind,
          message: 'Invalid sdk_minimum version "$raw".',
          severity: DiagnosticSeverity.error,
          evidence: ['params.version: $raw'],
        ),
      ];
    }
    final sdk = workspace.pubspec.environment.sdk;
    if (sdk == null) {
      return [
        PolicyFinding(
          ruleId: rule.id,
          kind: rule.kind,
          message: 'No environment.sdk declared; policy requires >= $min.',
          severity: DiagnosticSeverity.error,
          evidence: ['requiredMinimum: $min'],
        ),
      ];
    }
    if (!sdk.allows(min) && !_constraintAtLeast(sdk, min)) {
      return [
        PolicyFinding(
          ruleId: rule.id,
          kind: rule.kind,
          message: 'environment.sdk ($sdk) does not meet minimum $min.',
          severity: DiagnosticSeverity.error,
          evidence: ['sdk: $sdk', 'minimum: $min'],
          remediation: 'Raise environment.sdk to allow $min or higher.',
        ),
      ];
    }
    return const [];
  }

  bool _constraintAtLeast(VersionConstraint sdk, Version min) {
    if (sdk is VersionRange) {
      final lo = sdk.min;
      if (lo != null && lo >= min) return true;
    }
    if (sdk is Version && sdk >= min) return true;
    return sdk.allows(min);
  }

  List<PolicyFinding> _requireDirect(PolicyRule rule) {
    try {
      final findings = ImportAnalyzer(workspace).analyze();
      return [
        for (final f in findings)
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message:
                '"${f.package}" is imported but not declared as a direct dependency.',
            severity: DiagnosticSeverity.error,
            package: f.package,
            evidence: [for (final file in f.files.take(5)) file],
            remediation: 'Add "${f.package}" to dependencies.',
          ),
      ];
    } on Object catch (e) {
      return [
        PolicyFinding(
          ruleId: rule.id,
          kind: rule.kind,
          message: 'Could not evaluate require_direct_declaration: $e',
          severity: DiagnosticSeverity.warning,
          evidence: [e.toString()],
        ),
      ];
    }
  }

  List<PolicyFinding> _forbidden(PolicyRule rule) {
    final pkgs = _stringList(rule.params['packages']);
    final findings = <PolicyFinding>[];
    for (final name in pkgs) {
      final dep = workspace.pubspec.dependency(name) ??
          workspace.pubspec.overrideFor(name);
      if (dep != null) {
        findings.add(
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: 'Package "$name" is forbidden by policy.',
            severity: DiagnosticSeverity.error,
            package: name,
            evidence: ['declared in ${dep.section.name}'],
          ),
        );
      } else if (workspace.lockfile?[name] != null) {
        findings.add(
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: 'Forbidden package "$name" is present transitively.',
            severity: DiagnosticSeverity.warning,
            package: name,
            evidence: ['present in pubspec.lock'],
          ),
        );
      }
    }
    return findings;
  }

  List<PolicyFinding> _versionRanges(PolicyRule rule) {
    final ranges = rule.params['ranges'];
    if (ranges is! Map) return const [];
    final findings = <PolicyFinding>[];
    for (final e in ranges.entries) {
      final name = e.key.toString();
      final constraintRaw = e.value.toString();
      VersionConstraint expected;
      try {
        expected = VersionConstraint.parse(constraintRaw);
      } on Object {
        continue;
      }
      final locked = workspace.lockfile?[name]?.version;
      if (locked != null && !expected.allows(locked)) {
        findings.add(
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message:
                '"$name" locked at $locked is outside required range $expected.',
            severity: DiagnosticSeverity.error,
            package: name,
            evidence: ['locked: $locked', 'required: $expected'],
          ),
        );
      }
    }
    return findings;
  }

  List<PolicyFinding> _required(PolicyRule rule) {
    final pkgs = _stringList(rule.params['packages']);
    return [
      for (final name in pkgs)
        if (workspace.pubspec.dependency(name) == null)
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: 'Required package "$name" is not declared.',
            severity: DiagnosticSeverity.error,
            package: name,
            remediation: 'Add "$name" to dependencies.',
          ),
    ];
  }

  List<PolicyFinding> _maxAge(PolicyRule rule) {
    // Without network publish dates, report informational unknown.
    final days = rule.params['days'];
    return [
      PolicyFinding(
        ruleId: rule.id,
        kind: rule.kind,
        message:
            'max_age_days ($days) requires package metadata; run with network '
            'via `pubdoctor risk` for age evidence.',
        severity: DiagnosticSeverity.info,
        evidence: ['days: $days', 'localEvaluation: skipped'],
      ),
    ];
  }

  List<PolicyFinding> _noExternalGitPath(PolicyRule rule) {
    final findings = <PolicyFinding>[];
    for (final dep in [
      ...workspace.pubspec.allDependencies,
      ...workspace.pubspec.dependencyOverrides,
    ]) {
      if (dep.source == DependencySource.git) {
        findings.add(
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: 'Git dependency "${dep.name}" is forbidden by policy.',
            severity: DiagnosticSeverity.error,
            package: dep.name,
            evidence: [if (dep.gitUrl != null) 'git: ${dep.gitUrl}'],
          ),
        );
      }
      if (dep.source == DependencySource.path) {
        final path = dep.path ?? '';
        // Allow relative paths that stay within the project tree.
        if (path.contains('..') ||
            (path.length >= 2 && path[1] == ':') ||
            path.startsWith('/') ||
            path.startsWith('\\')) {
          findings.add(
            PolicyFinding(
              ruleId: rule.id,
              kind: rule.kind,
              message:
                  'Path dependency "${dep.name}" appears outside the workspace.',
              severity: DiagnosticSeverity.error,
              package: dep.name,
              evidence: ['path: $path'],
            ),
          );
        }
      }
    }
    return findings;
  }

  List<PolicyFinding> _noWildcards(PolicyRule rule) {
    final findings = <PolicyFinding>[];
    for (final dep in workspace.pubspec.allDependencies) {
      final c = dep.constraint.toString();
      if (c == 'any' || c.contains('*')) {
        findings.add(
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: 'Wildcard/any constraint on "${dep.name}" ($c) is banned.',
            severity: DiagnosticSeverity.error,
            package: dep.name,
            evidence: ['constraint: $c'],
            remediation: 'Pin to a caret or compatible range.',
          ),
        );
      }
    }
    return findings;
  }

  List<PolicyFinding> _pinnedSdk(PolicyRule rule) {
    final sdk = workspace.pubspec.environment.sdk;
    if (sdk == null || sdk.toString() == 'any') {
      return [
        PolicyFinding(
          ruleId: rule.id,
          kind: rule.kind,
          message: 'environment.sdk must be pinned (not any / missing).',
          severity: DiagnosticSeverity.error,
          evidence: ['sdk: ${sdk ?? 'missing'}'],
        ),
      ];
    }
    return const [];
  }

  Future<List<PolicyFinding>> _consistentWorkspace(PolicyRule rule) async {
    try {
      final report = await MonorepoAnalyzer().analyze(workspace.root.path);
      final diags = report.diagnostics.where(
        (d) => d.code == DiagnosticCodes.workspaceVersionInconsistent,
      );
      return [
        for (final d in diags)
          PolicyFinding(
            ruleId: rule.id,
            kind: rule.kind,
            message: d.message,
            severity: DiagnosticSeverity.error,
            package: d.package,
            evidence: d.evidence,
            remediation: d.remediation,
          ),
      ];
    } on Object {
      return const [];
    }
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return [for (final e in raw) e.toString()];
    }
    return const [];
  }
}
