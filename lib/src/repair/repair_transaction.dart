import 'dart:convert';

import '../healing/healing_policy.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../serialization/schema_version.dart';
import 'repair_plan.dart';

/// Transactional repair apply with rollback snapshots.
class RepairTransaction {
  /// Creates a transaction.
  RepairTransaction({
    required this.id,
    required this.rootPath,
    required FilesystemAdapter fs,
    required PathAdapter paths,
  })  : _fs = fs,
        _paths = paths;

  /// Transaction id.
  final String id;

  /// Workspace root.
  final String rootPath;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  final Map<String, String?> _backups = {};

  /// Snapshot path.
  String get snapshotDir =>
      _paths.join(rootPath, '.dart_tool', 'pubdoctor', 'repair', id);

  /// Begin — ensure dirs.
  void begin() {
    _fs.createDirectory(snapshotDir);
    _fs.writeText(
      _paths.join(snapshotDir, 'meta.json'),
      '${jsonEncode({
            'schemaVersion': SchemaVersions.repair,
            'id': id,
            'startedAt': DateTime.now().toUtc().toIso8601String(),
          })}\n',
    );
  }

  /// Record pre-image of [relativePath] then write [content].
  void writeFile(String relativePath, String content) {
    final abs = _paths.join(rootPath, relativePath);
    _backups.putIfAbsent(relativePath, () => _fs.readText(abs));
    final bak = _paths.join(snapshotDir, relativePath.replaceAll('/', '__'));
    final existing = _backups[relativePath];
    if (existing != null) {
      _fs.writeText(bak, existing);
    }
    _fs.writeText(abs, content);
  }

  /// Rollback all writes.
  void rollback() {
    for (final e in _backups.entries) {
      final abs = _paths.join(rootPath, e.key);
      if (e.value == null) {
        _fs.deleteFile(abs);
      } else {
        _fs.writeText(abs, e.value!);
      }
    }
  }

  /// Commit — keep journal.
  void commit({required bool success, String? message}) {
    _fs.writeText(
      _paths.join(snapshotDir, 'result.json'),
      '${jsonEncode({
            'success': success,
            if (message != null) 'message': message,
            'files': _backups.keys.toList(),
            'finishedAt': DateTime.now().toUtc().toIso8601String(),
          })}\n',
    );
  }
}

/// Validates repair plans statically.
class RepairValidator {
  /// Reject ambiguous / multi-choice candidates.
  List<String> validate(RepairPlan plan) {
    final errors = <String>[];
    for (final c in plan.candidates) {
      if (c.ambiguous) {
        errors.add('${c.id}: ambiguous — automatic repair disabled');
      }
      if (c.tier == SafetyTier.t4Behavioral) {
        errors.add('${c.id}: behavioral changes are never automatic');
      }
    }
    return errors;
  }
}
