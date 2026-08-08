import 'graph_models.dart';

/// Severity of a diagnostic finding.
enum DiagnosticSeverity {
  /// Informational note.
  info,

  /// Potential issue.
  warning,

  /// Clear problem.
  error,

  /// Blocking / critical problem.
  critical,
}

/// A structured diagnostic produced by analysis.
class Diagnostic {
  /// Creates a diagnostic.
  const Diagnostic({
    required this.code,
    required this.title,
    required this.message,
    required this.severity,
    this.package,
    this.evidence = const [],
    this.paths = const [],
    this.remediation,
  });

  /// Stable diagnostic code (e.g. `PD1001`).
  final String code;

  /// Short title.
  final String title;

  /// Detailed message.
  final String message;

  /// Severity.
  final DiagnosticSeverity severity;

  /// Affected package, if any.
  final String? package;

  /// Evidence strings (constraints, versions, etc.).
  final List<String> evidence;

  /// Relevant dependency paths.
  final List<DependencyPath> paths;

  /// Optional remediation guidance.
  final String? remediation;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'code': code,
        'title': title,
        'message': message,
        'severity': severity.name,
        if (package != null) 'package': package,
        if (evidence.isNotEmpty) 'evidence': evidence,
        if (paths.isNotEmpty) 'paths': paths.map((p) => p.toJson()).toList(),
        if (remediation != null) 'remediation': remediation,
      };
}

/// Well-known diagnostic codes.
abstract final class DiagnosticCodes {
  /// Empty constraint intersection.
  static const dependencyConflict = 'PD1001';

  /// Incompatible SDK constraint.
  static const incompatibleSdk = 'PD1002';

  /// Narrow / fragile constraint intersection.
  static const narrowConstraint = 'PD1003';

  /// Override appears unnecessary.
  static const unnecessaryOverride = 'PD1101';

  /// Override may be unsafe.
  static const unsafeOverride = 'PD1102';

  /// Override necessity unknown.
  static const unknownOverride = 'PD1103';

  /// Necessary override (informational).
  static const necessaryOverride = 'PD1104';

  /// Package unresolved / missing from lockfile.
  static const unresolvedPackage = 'PD1201';

  /// Direct import of a package not declared in the appropriate pubspec section.
  static const directImportNotDeclared = 'PD1301';

  /// Declared dependency appears unused (high/medium confidence only when reported).
  static const unusedDependency = 'PD1302';

  /// Dependency appears in the wrong pubspec section.
  static const misclassifiedDependency = 'PD1303';

  /// Duplicate dependency declarations across sections.
  static const duplicateDependency = 'PD1304';

  /// Suspicious or conflicting override configuration.
  static const suspiciousOverride = 'PD1305';

  /// Upgrade blocked by constraints.
  static const upgradeBlocked = 'PD1401';

  /// SDK upgrade blocked.
  static const sdkBlocked = 'PD1402';

  /// Workspace members disagree on a dependency version constraint.
  static const workspaceVersionInconsistent = 'PD1501';

  /// Workspace members disagree on SDK constraints.
  static const workspaceSdkInconsistent = 'PD1502';

  /// Conflicting overrides across workspace members.
  static const workspaceOverrideConflict = 'PD1503';

  /// Circular dependency among workspace packages.
  static const workspaceCircularDependency = 'PD1504';

  /// Discontinued / replacement risk signal.
  static const riskDiscontinued = 'PD1601';

  /// Maintenance / cadence risk signal.
  static const riskMaintenance = 'PD1602';

  /// Compatibility risk signal (SDK / majors).
  static const riskCompatibility = 'PD1603';

  /// Convergence / override risk signal.
  static const riskConvergence = 'PD1604';

  /// Transitive-but-imported risk signal.
  static const riskImport = 'PD1605';

  /// Concentration / chokepoint risk signal.
  static const riskConcentration = 'PD1606';

  /// Generic risk signal.
  static const riskGeneric = 'PD1607';

  /// Policy violation.
  static const policyViolation = 'PD1701';

  /// Migration plan risk / blocker.
  static const migrationBlocked = 'PD1801';

  /// Change impact warning.
  static const impactWarning = 'PD1901';

  /// Snapshot drift detected.
  static const snapshotDrift = 'PD2001';

  /// Analyzer module aborted the pipeline.
  static const moduleAborted = 'PD0008';

  /// Analyzer module failed but pipeline continued.
  static const moduleFailed = 'PD0009';
}
