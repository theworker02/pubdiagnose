/// Schema version constants for PubDoctor persisted formats.
abstract final class SchemaVersions {
  /// JSON CLI / inspect envelope.
  static const int json = 1;

  /// Baseline file.
  static const int baseline = 1;

  /// On-disk cache under `.dart_tool/pubdoctor`.
  static const int cache = 1;

  /// Recovery journal entries.
  static const int recovery = 1;

  /// `pubdoctor.yaml` config.
  static const int config = 1;

  /// Migration plans under `.dart_tool/pubdoctor/migrations/`.
  static const int migrations = 1;

  /// Project snapshots under `.dart_tool/pubdoctor/snapshots/`.
  static const int snapshots = 1;

  /// Policy document schema.
  static const int policy = 1;

  /// Healing journal under `.dart_tool/pubdoctor/healing/`.
  static const int healing = 1;

  /// Repair transaction journal.
  static const int repair = 1;
}
