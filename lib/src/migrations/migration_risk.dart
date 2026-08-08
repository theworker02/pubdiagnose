/// Risk classification for a migration step or plan.
enum MigrationRiskLevel {
  /// Unlikely to break consumers.
  low,

  /// May require code or constraint changes.
  moderate,

  /// Likely breaking or blocking.
  high,

  /// Cannot proceed without external changes.
  blocked,

  /// Insufficient evidence.
  unknown,
}

/// Risk attached to a migration step.
class MigrationRisk {
  /// Creates migration risk.
  const MigrationRisk({
    required this.level,
    required this.evidence,
    this.summary,
  });

  /// Risk level.
  final MigrationRiskLevel level;

  /// Evidence strings.
  final List<String> evidence;

  /// Optional summary.
  final String? summary;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'level': level.name,
        'evidence': evidence,
        if (summary != null) 'summary': summary,
      };
}
