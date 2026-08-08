import 'dart:convert';

import '../serialization/schema_version.dart';
import '../version.dart';
import 'healing_context.dart';

/// Append-only healing journal.
class HealingJournal {
  /// Creates a journal.
  HealingJournal(this.context);

  /// Context.
  final HealingContext context;

  /// Ensure layout.
  void ensureLayout() {
    context.cache.ensureLayout();
    context.fs.createDirectory(context.healingDir);
    context.fs.createDirectory(
      context.paths.join(context.healingDir, 'transactions'),
    );
    context.fs.createDirectory(
      context.paths.join(context.healingDir, 'snapshots'),
    );
    final marker = context.paths.join(context.healingDir, 'schema.json');
    if (!context.fs.fileExists(marker)) {
      context.fs.writeText(
        marker,
        '${jsonEncode({'schemaVersion': SchemaVersions.healing})}\n',
      );
    }
  }

  /// Journal path.
  String get journalPath =>
      context.paths.join(context.healingDir, 'journal.jsonl');

  /// Append an entry.
  void append(Map<String, Object?> entry) {
    ensureLayout();
    final line = jsonEncode({
      'schemaVersion': SchemaVersions.healing,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'pubdoctorVersion': pubdoctorPackageVersion,
      ...entry,
    });
    final existing = context.fs.readText(journalPath) ?? '';
    context.fs.writeText(journalPath, '$existing$line\n');
  }

  /// Read recent entries (newest last).
  List<Map<String, Object?>> recent({int limit = 50}) {
    ensureLayout();
    final raw = context.fs.readText(journalPath);
    if (raw == null || raw.trim().isEmpty) return const [];
    final out = <Map<String, Object?>>[];
    for (final line in raw.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        out.add(Map<String, Object?>.from(jsonDecode(line) as Map));
      } on Object {
        continue;
      }
    }
    if (out.length <= limit) return out;
    return out.sublist(out.length - limit);
  }
}
