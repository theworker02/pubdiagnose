import '../models/diagnostics.dart';

/// Catalog entry describing a diagnostic code for `pubdoctor explain`.
class DiagnosticCodeInfo {
  /// Creates catalog info.
  const DiagnosticCodeInfo({
    required this.code,
    required this.title,
    required this.meaning,
    required this.severity,
    required this.why,
    required this.fixes,
    required this.relatedCommand,
  });

  /// Code like PD1001.
  final String code;

  /// Short title.
  final String title;

  /// What it means.
  final String meaning;

  /// Typical severity.
  final DiagnosticSeverity severity;

  /// Why it is raised.
  final String why;

  /// Suggested fixes.
  final List<String> fixes;

  /// Related CLI command.
  final String relatedCommand;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'code': code,
        'title': title,
        'meaning': meaning,
        'severity': severity.name,
        'why': why,
        'fixes': fixes,
        'relatedCommand': relatedCommand,
      };
}

/// Static catalog of diagnostic codes.
abstract final class DiagnosticCatalog {
  /// All known entries.
  static const List<DiagnosticCodeInfo> all = [
    DiagnosticCodeInfo(
      code: DiagnosticCodes.dependencyConflict,
      title: 'Dependency conflict',
      meaning:
          'Dependents declare version constraints with an empty intersection.',
      severity: DiagnosticSeverity.error,
      why: 'Pub cannot pick one version that satisfies every constraint.',
      fixes: [
        'Loosen or align conflicting constraints.',
        'Upgrade a parent that pins an old range.',
        'Use dependency_overrides only temporarily.',
      ],
      relatedCommand: 'pubdoctor conflicts',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.incompatibleSdk,
      title: 'Incompatible SDK constraint',
      meaning: 'A package SDK constraint excludes the target SDK version.',
      severity: DiagnosticSeverity.error,
      why: 'The resolved graph cannot run on the requested SDK.',
      fixes: [
        'Upgrade the blocking package.',
        'Choose a different SDK target.',
      ],
      relatedCommand: 'pubdoctor sdk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.narrowConstraint,
      title: 'Narrow constraint intersection',
      meaning: 'Constraints intersect only over a fragile/narrow range.',
      severity: DiagnosticSeverity.warning,
      why: 'Small upstream changes may break resolution.',
      fixes: ['Align dependents on a shared, wider range.'],
      relatedCommand: 'pubdoctor conflicts',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.unnecessaryOverride,
      title: 'Possibly unnecessary override',
      meaning: 'A dependency_overrides entry may no longer be required.',
      severity: DiagnosticSeverity.info,
      why: 'Resolved versions appear to satisfy dependent constraints.',
      fixes: [
        'Test removal carefully with pubdoctor fix PD1101 or a manual edit.',
        'Run dart pub get after removal.',
      ],
      relatedCommand: 'pubdoctor overrides',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.unsafeOverride,
      title: 'Unsafe override',
      meaning:
          'An override forces a version outside dependents\' intersection.',
      severity: DiagnosticSeverity.warning,
      why: 'It can mask incompatibilities.',
      fixes: ['Prefer aligning upstream constraints.'],
      relatedCommand: 'pubdoctor overrides',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.unknownOverride,
      title: 'Unknown override necessity',
      meaning: 'Not enough evidence to classify the override.',
      severity: DiagnosticSeverity.info,
      why: 'Missing lockfile or incomplete dependency edges.',
      fixes: ['Run dart pub get and re-analyze.'],
      relatedCommand: 'pubdoctor overrides',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.necessaryOverride,
      title: 'Necessary override',
      meaning: 'An override appears required due to conflicting constraints.',
      severity: DiagnosticSeverity.info,
      why: 'Dependents declare incompatible ranges.',
      fixes: ['Align upstream constraints before removing the override.'],
      relatedCommand: 'pubdoctor overrides',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.unresolvedPackage,
      title: 'Unresolved package',
      meaning:
          'A package was expected but not found in the graph or repository.',
      severity: DiagnosticSeverity.error,
      why: 'Missing declaration, failed resolve, or unknown name.',
      fixes: ['Verify the package name and run dart pub get.'],
      relatedCommand: 'pubdoctor why',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.directImportNotDeclared,
      title: 'Direct import not declared',
      meaning:
          'Source imports a package not declared in the appropriate pubspec '
          'section (often transitive-only).',
      severity: DiagnosticSeverity.warning,
      why: 'Transitive dependencies are not a stable API of your package.',
      fixes: [
        'Add the package to dependencies or dev_dependencies.',
        'Or stop importing it directly.',
      ],
      relatedCommand: 'pubdoctor imports',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.unusedDependency,
      title: 'Possibly unused dependency',
      meaning: 'A declared dependency has no corresponding package: import.',
      severity: DiagnosticSeverity.warning,
      why: 'It may be dead weight — or tooling used without imports.',
      fixes: [
        'Remove only high-confidence unused deps after verification.',
      ],
      relatedCommand: 'pubdoctor unused',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.misclassifiedDependency,
      title: 'Misclassified dependency',
      meaning: 'A package appears in the wrong pubspec section.',
      severity: DiagnosticSeverity.warning,
      why: 'Incorrect section affects consumers and resolution.',
      fixes: ['Move the package to the correct section.'],
      relatedCommand: 'pubdoctor check',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.duplicateDependency,
      title: 'Duplicate dependency',
      meaning: 'The same package is listed in multiple pubspec sections.',
      severity: DiagnosticSeverity.error,
      why: 'Ambiguous intent and fragile configuration.',
      fixes: ['Keep a single declaration.'],
      relatedCommand: 'pubdoctor check',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.suspiciousOverride,
      title: 'Suspicious override',
      meaning: 'An override looks risky or unexplained.',
      severity: DiagnosticSeverity.warning,
      why: 'Overrides bypass normal constraint solving.',
      fixes: ['Document and minimize overrides.'],
      relatedCommand: 'pubdoctor overrides',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.upgradeBlocked,
      title: 'Upgrade blocked',
      meaning: 'A newer package version is excluded by current constraints.',
      severity: DiagnosticSeverity.info,
      why: 'One or more dependents pin an incompatible range.',
      fixes: ['Use pubdoctor unlock <package>.'],
      relatedCommand: 'pubdoctor unlock',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.sdkBlocked,
      title: 'SDK upgrade blocked',
      meaning: 'A locked package rejects the target Dart/Flutter SDK.',
      severity: DiagnosticSeverity.error,
      why: 'Package environment constraints exclude the SDK version.',
      fixes: ['Upgrade the blocking package or pick another SDK target.'],
      relatedCommand: 'pubdoctor sdk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.workspaceVersionInconsistent,
      title: 'Workspace version inconsistency',
      meaning: 'Workspace members disagree on an external package constraint.',
      severity: DiagnosticSeverity.warning,
      why: 'Monorepo resolution becomes harder.',
      fixes: ['Align constraints across workspace members.'],
      relatedCommand: 'pubdoctor workspace',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.workspaceSdkInconsistent,
      title: 'Workspace SDK inconsistency',
      meaning: 'Workspace members declare different SDK environments.',
      severity: DiagnosticSeverity.warning,
      why: 'Shared tooling/CI may not satisfy every member.',
      fixes: ['Align environment.sdk where practical.'],
      relatedCommand: 'pubdoctor workspace',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.workspaceOverrideConflict,
      title: 'Workspace override conflict',
      meaning: 'Members declare conflicting dependency_overrides.',
      severity: DiagnosticSeverity.error,
      why: 'Incompatible overrides cannot all be honored.',
      fixes: ['Consolidate overrides at the workspace root when possible.'],
      relatedCommand: 'pubdoctor workspace',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.workspaceCircularDependency,
      title: 'Workspace circular dependency',
      meaning: 'Workspace packages depend on each other in a cycle.',
      severity: DiagnosticSeverity.warning,
      why: 'Cycles complicate analysis and release ordering.',
      fixes: ['Extract a shared package to break the cycle.'],
      relatedCommand: 'pubdoctor workspace',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.moduleAborted,
      title: 'Analyzer module aborted',
      meaning: 'A required analyzer module failed and stopped the pipeline.',
      severity: DiagnosticSeverity.error,
      why: 'Fault isolation could not continue safely.',
      fixes: [
        'Run pubdoctor doctor-report.',
        'Retry with --offline if network metadata failed.',
      ],
      relatedCommand: 'pubdoctor doctor-report',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.moduleFailed,
      title: 'Analyzer module failed',
      meaning: 'An optional analyzer module failed; other analysis continued.',
      severity: DiagnosticSeverity.warning,
      why: 'Modules are fault-isolated so local graph analysis still runs.',
      fixes: [
        'Inspect the module error in verbose output.',
        'Run pubdoctor recover if cache/state looks corrupt.',
      ],
      relatedCommand: 'pubdoctor check',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskDiscontinued,
      title: 'Discontinued / replacement risk',
      meaning: 'A dependency is discontinued or has a documented replacement.',
      severity: DiagnosticSeverity.critical,
      why:
          'Continuing on discontinued packages accumulates security and compat debt.',
      fixes: [
        'Migrate to the replacement or an actively maintained alternative.'
      ],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskMaintenance,
      title: 'Maintenance risk',
      meaning:
          'Release cadence or pre-release-only signals indicate maintenance risk.',
      severity: DiagnosticSeverity.warning,
      why: 'Stale packages may not track SDK or security updates.',
      fixes: ['Verify upstream activity; plan replacements if abandoned.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskCompatibility,
      title: 'Compatibility risk',
      meaning:
          'SDK or major-version compatibility evidence indicates upgrade friction.',
      severity: DiagnosticSeverity.error,
      why: 'Old majors and stale SDK constraints block migrations.',
      fixes: ['Plan a major upgrade or SDK-compatible release.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskConvergence,
      title: 'Convergence / override risk',
      meaning:
          'Constraint conflicts or necessary overrides signal resolution fragility.',
      severity: DiagnosticSeverity.error,
      why: 'The graph cannot converge cleanly without overrides.',
      fixes: ['Align constraints; remove overrides when safe.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskImport,
      title: 'Transitive import risk',
      meaning:
          'A transitive package is imported directly without a declaration.',
      severity: DiagnosticSeverity.warning,
      why: 'Pub does not guarantee transitive packages remain importable.',
      fixes: ['Declare the package in dependencies.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskConcentration,
      title: 'Concentration chokepoint',
      meaning: 'Many dependency paths pass through one transitive package.',
      severity: DiagnosticSeverity.warning,
      why: 'Upgrades of chokepoint packages have outsized blast radius.',
      fixes: ['Treat upgrades carefully; consider impact analysis.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.riskGeneric,
      title: 'Dependency risk signal',
      meaning: 'An evidence-backed risk signal was raised.',
      severity: DiagnosticSeverity.info,
      why:
          'Risk intelligence aggregates factual signals without opaque scores.',
      fixes: ['Inspect evidence with pubdoctor risk --json.'],
      relatedCommand: 'pubdoctor risk',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.policyViolation,
      title: 'Policy violation',
      meaning: 'A configured workspace governance policy was violated.',
      severity: DiagnosticSeverity.error,
      why: 'CI / team policy enforces dependency hygiene.',
      fixes: ['Fix the violation or adjust pubdoctor.yaml policies.'],
      relatedCommand: 'pubdoctor policy',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.migrationBlocked,
      title: 'Migration blocked',
      meaning: 'A migration step cannot proceed given current evidence.',
      severity: DiagnosticSeverity.error,
      why: 'Prerequisites or package blockers prevent the planned change.',
      fixes: ['Resolve blockers; run pubdoctor migrate --status.'],
      relatedCommand: 'pubdoctor migrate',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.impactWarning,
      title: 'Change impact warning',
      meaning: 'A simulated change affects multiple packages or looks unsafe.',
      severity: DiagnosticSeverity.warning,
      why: 'Reverse-dependency analysis found blast radius or import usage.',
      fixes: ['Review affected packages; update importers before removal.'],
      relatedCommand: 'pubdoctor impact',
    ),
    DiagnosticCodeInfo(
      code: DiagnosticCodes.snapshotDrift,
      title: 'Snapshot drift',
      meaning:
          'Current project state differs from a stored intelligence snapshot.',
      severity: DiagnosticSeverity.warning,
      why: 'Dependencies, lockfile, diagnostics, or risk signals changed.',
      fixes: ['Review drift; update snapshot if intentional.'],
      relatedCommand: 'pubdoctor drift',
    ),
  ];

  /// Lookup by code (case-insensitive).
  static DiagnosticCodeInfo? byCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final e in all) {
      if (e.code == normalized) return e;
    }
    return null;
  }
}
