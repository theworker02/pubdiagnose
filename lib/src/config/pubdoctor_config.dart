import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/diagnostics.dart';
import '../models/exceptions.dart';
import '../policy/policy_parser.dart';
import '../policy/policy_rule.dart';
import '../remote/remote_workspace.dart';
import '../security/package_integrity.dart';

/// Validated pubdoctor.yaml configuration.
class PubDoctorConfig {
  /// Creates a config.
  const PubDoctorConfig({
    this.severities = const {},
    this.ignore = const [],
    this.failOn = DiagnosticSeverity.error,
    this.policies = const [],
    this.largeWorkspace = false,
    this.security = SecurityPolicy.defaults,
    this.memoryBudget = const MemoryBudget(),
    this.sourcePath,
  });

  /// Default config.
  static const defaults = PubDoctorConfig();

  /// Per-code severity overrides (`PD1001` → severity name).
  final Map<String, DiagnosticSeverity> severities;

  /// Diagnostic codes or package names to ignore.
  final List<String> ignore;

  /// CI fail-on threshold.
  final DiagnosticSeverity failOn;

  /// Governance policies.
  final List<PolicyRule> policies;

  /// Prefer bounded path expansion for large workspaces.
  final bool largeWorkspace;

  /// Supply-chain security policy.
  final SecurityPolicy security;

  /// Soft memory budgets.
  final MemoryBudget memoryBudget;

  /// Path loaded from, if any.
  final String? sourcePath;

  /// Whether [diagnostic] is ignored by config.
  bool isIgnored(Diagnostic diagnostic) {
    final code = diagnostic.code.toUpperCase();
    if (ignore.map((e) => e.toUpperCase()).contains(code)) return true;
    if (diagnostic.package != null && ignore.contains(diagnostic.package)) {
      return true;
    }
    return false;
  }

  /// Effective severity for [diagnostic].
  DiagnosticSeverity severityFor(Diagnostic diagnostic) {
    return severities[diagnostic.code.toUpperCase()] ?? diagnostic.severity;
  }

  /// Filter + remap diagnostics.
  List<Diagnostic> apply(List<Diagnostic> input) {
    final out = <Diagnostic>[];
    for (final d in input) {
      if (isIgnored(d)) continue;
      final sev = severityFor(d);
      if (sev == d.severity) {
        out.add(d);
      } else {
        out.add(
          Diagnostic(
            code: d.code,
            title: d.title,
            message: d.message,
            severity: sev,
            package: d.package,
            evidence: d.evidence,
            paths: d.paths,
            remediation: d.remediation,
          ),
        );
      }
    }
    return out;
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'severities': {
          for (final e in severities.entries) e.key: e.value.name,
        },
        'ignore': ignore,
        'ci': {'fail_on': failOn.name},
        'policies': [for (final p in policies) p.toJson()],
        'largeWorkspace': largeWorkspace,
        'security': security.toJson(),
        'memoryBudget': memoryBudget.toJson(),
        if (sourcePath != null) 'sourcePath': sourcePath,
      };
}

/// Loads and validates `pubdoctor.yaml`.
class ConfigLoader {
  /// Load from [projectDir], or defaults if missing.
  static PubDoctorConfig load(String projectDir) {
    final file = File(p.join(projectDir, 'pubdoctor.yaml'));
    if (!file.existsSync()) {
      final alt = File(p.join(projectDir, '.pubdoctor.yaml'));
      if (!alt.existsSync()) return PubDoctorConfig.defaults;
      return _parse(alt.readAsStringSync(), alt.path);
    }
    return _parse(file.readAsStringSync(), file.path);
  }

  static PubDoctorConfig _parse(String content, String source) {
    late final YamlNode root;
    try {
      root = loadYamlNode(content);
    } on Object catch (e) {
      throw InvalidYamlException(source, e);
    }
    if (root is! YamlMap) {
      throw InvalidProjectException(
        'pubdoctor.yaml root must be a map ($source).',
        code: 'PD0007',
      );
    }

    final unknown = <String>[];
    const known = {
      'rules',
      'ignore',
      'ci',
      'severities',
      'policies',
      'large_workspace',
      'security',
      'memory',
    };
    for (final key in root.keys) {
      final name = key.toString();
      if (!known.contains(name)) unknown.add(name);
    }
    if (unknown.isNotEmpty) {
      throw InvalidProjectException(
        'Unknown key(s) in pubdoctor.yaml: ${unknown.join(', ')}. '
        'Known keys: rules, severities, ignore, ci, policies, large_workspace, '
        'security, memory.',
        code: 'PD0007',
      );
    }

    final severities = <String, DiagnosticSeverity>{};
    void readSeverities(Object? raw) {
      if (raw is! YamlMap) return;
      for (final e in raw.entries) {
        final code = e.key.toString().toUpperCase();
        final sev = _severity(e.value?.toString());
        if (sev == null) {
          throw InvalidProjectException(
            'Invalid severity for $code in $source: ${e.value}',
            code: 'PD0007',
          );
        }
        severities[code] = sev;
      }
    }

    readSeverities(root['severities']);
    final rules = root['rules'];
    if (rules is YamlMap) {
      readSeverities(rules['severities']);
      // rules.<code>.severity
      for (final e in rules.entries) {
        final key = e.key.toString();
        if (key == 'severities') continue;
        final value = e.value;
        if (value is YamlMap && value['severity'] != null) {
          final sev = _severity(value['severity']?.toString());
          if (sev == null) {
            throw InvalidProjectException(
              'Invalid severity for rule $key in $source.',
              code: 'PD0007',
            );
          }
          severities[key.toUpperCase()] = sev;
        }
      }
    }

    final ignore = <String>[];
    final ignoreRaw = root['ignore'];
    if (ignoreRaw is YamlList) {
      for (final item in ignoreRaw) {
        if (item != null) ignore.add(item.toString());
      }
    } else if (ignoreRaw != null) {
      throw InvalidProjectException(
        'ignore must be a list in $source.',
        code: 'PD0007',
      );
    }

    var failOn = DiagnosticSeverity.error;
    final ci = root['ci'];
    if (ci is YamlMap) {
      for (final key in ci.keys) {
        if (key.toString() != 'fail_on') {
          throw InvalidProjectException(
            'Unknown ci key "$key" in $source. Known: fail_on.',
            code: 'PD0007',
          );
        }
      }
      final raw = ci['fail_on']?.toString();
      if (raw != null) {
        final sev = _severity(raw);
        if (sev == null) {
          throw InvalidProjectException(
            'Invalid ci.fail_on "$raw" in $source.',
            code: 'PD0007',
          );
        }
        failOn = sev;
      }
    } else if (ci != null) {
      throw InvalidProjectException(
        'ci must be a map in $source.',
        code: 'PD0007',
      );
    }

    final policies = PolicyParser.parseYamlMap(root, source: source);
    final largeWorkspace = root['large_workspace'] == true;

    SecurityPolicy security = SecurityPolicy.defaults;
    final securityRaw = root['security'];
    if (securityRaw is YamlMap) {
      security = SecurityPolicy.fromMap(securityRaw);
    } else if (securityRaw != null) {
      throw InvalidProjectException(
        'security must be a map in $source.',
        code: 'PD0007',
      );
    }

    var memoryBudget = const MemoryBudget();
    final memoryRaw = root['memory'];
    if (memoryRaw is YamlMap) {
      memoryBudget = MemoryBudget(
        sourceIndexBytes: (memoryRaw['source_index_bytes'] as num?)?.toInt() ??
            memoryBudget.sourceIndexBytes,
        metadataCacheBytes:
            (memoryRaw['metadata_cache_bytes'] as num?)?.toInt() ??
                memoryBudget.metadataCacheBytes,
        graphBytes: (memoryRaw['graph_bytes'] as num?)?.toInt() ??
            memoryBudget.graphBytes,
        snapshotRetention: (memoryRaw['snapshot_retention'] as num?)?.toInt() ??
            memoryBudget.snapshotRetention,
      );
    } else if (memoryRaw != null) {
      throw InvalidProjectException(
        'memory must be a map in $source.',
        code: 'PD0007',
      );
    }

    return PubDoctorConfig(
      severities: severities,
      ignore: ignore,
      failOn: failOn,
      policies: policies,
      largeWorkspace: largeWorkspace,
      security: security,
      memoryBudget: memoryBudget,
      sourcePath: source,
    );
  }

  static DiagnosticSeverity? _severity(String? raw) {
    if (raw == null) return null;
    switch (raw.toLowerCase()) {
      case 'info':
        return DiagnosticSeverity.info;
      case 'warning':
        return DiagnosticSeverity.warning;
      case 'error':
        return DiagnosticSeverity.error;
      case 'critical':
        return DiagnosticSeverity.critical;
      default:
        return null;
    }
  }
}
