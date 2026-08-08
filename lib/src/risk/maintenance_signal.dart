import 'risk_signal.dart';

/// Maintenance-oriented signal helpers (cadence, abandonment, pre-release).
abstract final class MaintenanceSignals {
  /// Discontinued package.
  static RiskSignal discontinued({
    required String package,
    String? replacedBy,
  }) {
    final evidence = <String>[
      'pub.dev marks "$package" as discontinued',
      if (replacedBy != null) 'replacement suggested: $replacedBy',
    ];
    return RiskSignal(
      id: 'discontinued',
      category: RiskCategory.critical,
      confidence: RiskConfidence.high,
      title: 'Discontinued package',
      message: replacedBy == null
          ? '"$package" is discontinued on pub.dev.'
          : '"$package" is discontinued; replaced by "$replacedBy".',
      evidence: evidence,
      package: package,
      remediation: replacedBy == null
          ? 'Find an actively maintained alternative.'
          : 'Migrate to "$replacedBy".',
    );
  }

  /// Explicit replacement available.
  static RiskSignal replacement({
    required String package,
    required String replacedBy,
  }) {
    return RiskSignal(
      id: 'replacement',
      category: RiskCategory.high,
      confidence: RiskConfidence.high,
      title: 'Replacement available',
      message: '"$package" has a documented replacement: "$replacedBy".',
      evidence: ['replacedBy: $replacedBy'],
      package: package,
      remediation: 'Plan migration to "$replacedBy".',
    );
  }

  /// No publish activity for a long period.
  static RiskSignal abandonedCadence({
    required String package,
    required Duration age,
    Duration threshold = const Duration(days: 730),
  }) {
    final days = age.inDays;
    final category = days >= threshold.inDays * 2
        ? RiskCategory.high
        : RiskCategory.moderate;
    return RiskSignal(
      id: 'abandoned_cadence',
      category: category,
      confidence: RiskConfidence.medium,
      title: 'Stale release cadence',
      message: 'Latest stable release of "$package" is $days days old '
          '(threshold ${threshold.inDays} days).',
      evidence: [
        'latestStableAgeDays: $days',
        'thresholdDays: ${threshold.inDays}',
      ],
      package: package,
      remediation: 'Verify maintenance status and consider alternatives.',
    );
  }

  /// Only pre-release versions are newer than locked/stable.
  static RiskSignal preReleaseOnly({
    required String package,
    required String latest,
    String? latestStable,
  }) {
    return RiskSignal(
      id: 'pre_release_only',
      category: RiskCategory.moderate,
      confidence: RiskConfidence.high,
      title: 'Pre-release-only newer versions',
      message: latestStable == null
          ? '"$package" has no stable releases; latest is $latest.'
          : '"$package" latest ($latest) is pre-release; stable is $latestStable.',
      evidence: [
        'latest: $latest',
        if (latestStable != null) 'latestStable: $latestStable',
      ],
      package: package,
    );
  }
}
