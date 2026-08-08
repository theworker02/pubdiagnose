/// Confidence that a healing action is correct.
enum HealingConfidence {
  /// Deterministic / certain.
  certain,

  /// High confidence.
  high,

  /// Medium.
  medium,

  /// Low.
  low,

  /// Unknown.
  unknown,
}

/// Risk of applying a healing action.
enum HealingRisk {
  /// Safe internal state only.
  low,

  /// May affect caches broadly.
  moderate,

  /// High risk — never auto.
  high,
}

/// Safety tier (T0–T4).
enum SafetyTier {
  /// Internal PubDoctor recovery (auto OK).
  t0Internal,

  /// Deterministic project metadata (needs safe permission).
  t1Metadata,

  /// Deterministic Dart source (explicit repair permission).
  t2Source,

  /// Ambiguous API migration (preview only).
  t3AmbiguousApi,

  /// Behavioral — never auto-guess.
  t4Behavioral,
}
