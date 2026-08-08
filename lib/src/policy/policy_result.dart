import '../models/diagnostics.dart';
import 'policy_rule.dart';

/// Outcome of evaluating one policy rule.
class PolicyFinding {
  /// Creates a finding.
  const PolicyFinding({
    required this.ruleId,
    required this.kind,
    required this.message,
    required this.severity,
    this.package,
    this.evidence = const [],
    this.remediation,
  });

  /// Rule id.
  final String ruleId;

  /// Rule kind.
  final PolicyRuleKind kind;

  /// Message.
  final String message;

  /// Severity.
  final DiagnosticSeverity severity;

  /// Package, if any.
  final String? package;

  /// Evidence.
  final List<String> evidence;

  /// Remediation.
  final String? remediation;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'ruleId': ruleId,
        'kind': kind.name,
        'message': message,
        'severity': severity.name,
        if (package != null) 'package': package,
        if (evidence.isNotEmpty) 'evidence': evidence,
        if (remediation != null) 'remediation': remediation,
      };

  /// As diagnostic.
  Diagnostic toDiagnostic() => Diagnostic(
        code: DiagnosticCodes.policyViolation,
        title: 'Policy: ${kind.name}',
        message: message,
        severity: severity,
        package: package,
        evidence: evidence,
        remediation: remediation,
      );
}

/// Aggregated policy check result.
class PolicyResult {
  /// Creates a result.
  const PolicyResult({
    required this.findings,
    required this.rulesEvaluated,
    this.sourcePath,
  });

  /// Findings (violations).
  final List<PolicyFinding> findings;

  /// Rules that were evaluated.
  final int rulesEvaluated;

  /// Config source path.
  final String? sourcePath;

  /// Whether any error/critical findings exist.
  bool get hasViolations => findings.any(
        (f) =>
            f.severity == DiagnosticSeverity.error ||
            f.severity == DiagnosticSeverity.critical,
      );

  /// Diagnostics.
  List<Diagnostic> get diagnostics =>
      [for (final f in findings) f.toDiagnostic()];

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'rulesEvaluated': rulesEvaluated,
        'violationCount': findings.length,
        'hasViolations': hasViolations,
        if (sourcePath != null) 'sourcePath': sourcePath,
        'findings': [for (final f in findings) f.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };
}
