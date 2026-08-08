import 'package:yaml/yaml.dart';

import '../models/exceptions.dart';
import 'policy_rule.dart';

/// Parses `policies:` from pubdoctor.yaml (or a dedicated policies map).
class PolicyParser {
  /// Parse policies from a YAML root map (pubdoctor.yaml root).
  static List<PolicyRule> parseYamlMap(YamlMap root, {String? source}) {
    final raw = root['policies'];
    if (raw == null) return const [];
    if (raw is! YamlMap) {
      throw InvalidProjectException(
        'policies must be a map${source != null ? ' in $source' : ''}.',
        code: 'PD0007',
      );
    }
    return parsePoliciesMap(raw, source: source);
  }

  /// Parse the policies map itself.
  static List<PolicyRule> parsePoliciesMap(
    YamlMap policies, {
    String? source,
  }) {
    final rules = <PolicyRule>[];

    void addBoolRule(String key, PolicyRuleKind kind) {
      final v = policies[key];
      if (v == null) return;
      final enabled = v == true || v == 'true';
      if (v is YamlMap) {
        rules.add(
          PolicyRule(
            id: key,
            kind: kind,
            scope: _scope(v),
            enabled: v['enabled'] != false,
            params: _params(v),
            description: v['description']?.toString(),
          ),
        );
      } else {
        rules.add(
          PolicyRule(
            id: key,
            kind: kind,
            scope: PolicyScope.root,
            enabled: enabled,
          ),
        );
      }
    }

    addBoolRule('ban_overrides', PolicyRuleKind.banOverrides);
    addBoolRule(
        'require_direct_declaration', PolicyRuleKind.requireDirectDeclaration);
    addBoolRule('no_wildcards', PolicyRuleKind.noWildcards);
    addBoolRule('pinned_sdk', PolicyRuleKind.pinnedSdk);
    addBoolRule('consistent_workspace_versions',
        PolicyRuleKind.consistentWorkspaceVersions);
    addBoolRule(
        'no_git_path_outside_workspace', PolicyRuleKind.noExternalGitPath);

    final sdkMin = policies['sdk_minimum'];
    if (sdkMin != null) {
      if (sdkMin is YamlMap) {
        rules.add(
          PolicyRule(
            id: 'sdk_minimum',
            kind: PolicyRuleKind.sdkMinimum,
            scope: _scope(sdkMin),
            enabled: sdkMin['enabled'] != false,
            params: {
              'version':
                  sdkMin['version']?.toString() ?? sdkMin['min']?.toString(),
              ..._params(sdkMin),
            },
          ),
        );
      } else {
        rules.add(
          PolicyRule(
            id: 'sdk_minimum',
            kind: PolicyRuleKind.sdkMinimum,
            scope: PolicyScope.root,
            params: {'version': sdkMin.toString()},
          ),
        );
      }
    }

    final forbidden = policies['forbidden_packages'];
    if (forbidden is YamlList) {
      rules.add(
        PolicyRule(
          id: 'forbidden_packages',
          kind: PolicyRuleKind.forbiddenPackages,
          scope: PolicyScope.root,
          params: {
            'packages': [for (final e in forbidden) e.toString()],
          },
        ),
      );
    }

    final required = policies['required_packages'];
    if (required is YamlList) {
      rules.add(
        PolicyRule(
          id: 'required_packages',
          kind: PolicyRuleKind.requiredPackages,
          scope: PolicyScope.root,
          params: {
            'packages': [for (final e in required) e.toString()],
          },
        ),
      );
    }

    final ranges = policies['version_ranges'];
    if (ranges is YamlMap) {
      final map = <String, String>{};
      for (final e in ranges.entries) {
        map[e.key.toString()] = e.value.toString();
      }
      rules.add(
        PolicyRule(
          id: 'version_ranges',
          kind: PolicyRuleKind.versionRanges,
          scope: PolicyScope.root,
          params: {'ranges': map},
        ),
      );
    }

    final maxAge = policies['max_age_days'];
    if (maxAge != null) {
      rules.add(
        PolicyRule(
          id: 'max_age_days',
          kind: PolicyRuleKind.maxAge,
          scope: PolicyScope.root,
          params: {'days': int.tryParse(maxAge.toString()) ?? 730},
        ),
      );
    }

    // Nested scopes: policies.scopes.<package>:
    final scopes = policies['scopes'];
    if (scopes is YamlMap) {
      for (final e in scopes.entries) {
        final pkg = e.key.toString();
        final body = e.value;
        if (body is! YamlMap) continue;
        final nested = parsePoliciesMap(body, source: source);
        for (final r in nested) {
          rules.add(
            PolicyRule(
              id: '${r.id}@$pkg',
              kind: r.kind,
              scope: PolicyScope(
                package: pkg,
                inherit: body['inherit'] != false,
                overrideParent: body['override'] == true,
              ),
              enabled: r.enabled,
              params: r.params,
              description: r.description,
            ),
          );
        }
      }
    }

    return rules;
  }

  static PolicyScope _scope(YamlMap map) {
    return PolicyScope(
      package: map['package']?.toString(),
      inherit: map['inherit'] != false,
      overrideParent: map['override'] == true,
    );
  }

  static Map<String, Object?> _params(YamlMap map) {
    final out = <String, Object?>{};
    for (final e in map.entries) {
      final k = e.key.toString();
      if ({
        'enabled',
        'description',
        'inherit',
        'override',
        'package',
        'version',
        'min'
      }.contains(k)) {
        continue;
      }
      out[k] = e.value;
    }
    return out;
  }

  /// Built-in empty / default policy set.
  static List<PolicyRule> defaults() => const [];
}
