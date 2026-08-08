import 'risk_signal.dart';

/// Compatibility-oriented signal helpers.
abstract final class CompatibilitySignals {
  /// Package SDK constraint is stale relative to project or ecosystem.
  static RiskSignal staleSdk({
    required String package,
    required String packageSdk,
    required String projectSdk,
  }) {
    return RiskSignal(
      id: 'stale_sdk',
      category: RiskCategory.moderate,
      confidence: RiskConfidence.medium,
      title: 'Stale package SDK constraint',
      message: '"$package" declares SDK $packageSdk while the project uses '
          '$projectSdk.',
      evidence: [
        'packageSdk: $packageSdk',
        'projectSdk: $projectSdk',
      ],
      package: package,
      remediation:
          'Upgrade "$package" to a release that supports the project SDK.',
    );
  }

  /// Direct dependency pinned to an old major relative to latest stable.
  static RiskSignal oldMajorPin({
    required String package,
    required String locked,
    required String latestStable,
    required int lockedMajor,
    required int latestMajor,
  }) {
    return RiskSignal(
      id: 'old_major_pin',
      category: RiskCategory.high,
      confidence: RiskConfidence.high,
      title: 'Old major version pin',
      message:
          '"$package" is locked at $locked (major $lockedMajor) while latest '
          'stable is $latestStable (major $latestMajor).',
      evidence: [
        'locked: $locked',
        'latestStable: $latestStable',
        'majorsBehind: ${latestMajor - lockedMajor}',
      ],
      package: package,
      remediation: 'Plan a major-version upgrade for "$package".',
    );
  }

  /// No stable release compatible with a target SDK.
  static RiskSignal noStableSdkCompatible({
    required String package,
    required String targetSdk,
  }) {
    return RiskSignal(
      id: 'no_stable_sdk_compatible',
      category: RiskCategory.critical,
      confidence: RiskConfidence.high,
      title: 'No stable SDK-compatible release',
      message: 'No stable release of "$package" satisfies SDK $targetSdk.',
      evidence: ['targetSdk: $targetSdk'],
      package: package,
      remediation: 'Find an alternative or wait for a compatible release.',
    );
  }

  /// Package blocks an SDK migration.
  static RiskSignal blocksSdkMigration({
    required String package,
    required String targetSdk,
    required String reason,
  }) {
    return RiskSignal(
      id: 'blocks_sdk_migration',
      category: RiskCategory.high,
      confidence: RiskConfidence.high,
      title: 'Blocks SDK migration',
      message: '"$package" blocks migration to SDK $targetSdk: $reason',
      evidence: ['targetSdk: $targetSdk', 'reason: $reason'],
      package: package,
      remediation: 'Upgrade or replace "$package" before migrating the SDK.',
    );
  }

  /// Dependency requires overrides to resolve.
  static RiskSignal requiresOverrides({
    required String package,
    required String explanation,
  }) {
    return RiskSignal(
      id: 'requires_overrides',
      category: RiskCategory.high,
      confidence: RiskConfidence.medium,
      title: 'Requires dependency overrides',
      message: '"$package" appears to require dependency_overrides.',
      evidence: [explanation],
      package: package,
      remediation: 'Align constraints so the override can be removed.',
    );
  }

  /// Graph convergence / conflict problems.
  static RiskSignal convergenceProblems({
    required String package,
    required List<String> evidence,
  }) {
    return RiskSignal(
      id: 'convergence_problems',
      category: RiskCategory.high,
      confidence: RiskConfidence.high,
      title: 'Constraint convergence problems',
      message: 'Dependents cannot converge on a single version of "$package".',
      evidence: evidence,
      package: package,
      remediation: 'Align dependent constraints on "$package".',
    );
  }
}
