import 'dart:convert';

import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../serialization/schema_version.dart';

/// On-disk cache / state / recovery root under `.dart_tool/pubdoctor/`.
class CacheStore {
  /// Creates a store rooted at [rootPath] (usually project `.dart_tool/pubdoctor`).
  CacheStore({
    required this.rootPath,
    required FilesystemAdapter fs,
    required PathAdapter paths,
  })  : _fs = fs,
        _paths = paths;

  /// Create under [workspacePath]/.dart_tool/pubdoctor.
  factory CacheStore.forWorkspace(
    String workspacePath, {
    required FilesystemAdapter fs,
    required PathAdapter paths,
  }) {
    final root = paths.join(workspacePath, '.dart_tool', 'pubdoctor');
    return CacheStore(rootPath: root, fs: fs, paths: paths);
  }

  /// Root directory.
  final String rootPath;

  /// Filesystem adapter.
  FilesystemAdapter get fs => _fs;

  /// Path adapter.
  PathAdapter get paths => _paths;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  /// Cache subdirectory.
  String get cacheDir => _paths.join(rootPath, 'cache');

  /// State subdirectory.
  String get stateDir => _paths.join(rootPath, 'state');

  /// Recovery journal directory.
  String get recoveryDir => _paths.join(rootPath, 'recovery');

  /// Logs directory.
  String get logsDir => _paths.join(rootPath, 'logs');

  /// Ensure directory tree exists.
  void ensureLayout() {
    for (final d in [rootPath, cacheDir, stateDir, recoveryDir, logsDir]) {
      _fs.createDirectory(d);
    }
    final marker = _paths.join(rootPath, 'schema.json');
    if (!_fs.fileExists(marker)) {
      final body = const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': SchemaVersions.cache,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      _fs.writeText(marker, '$body\n');
    }
  }

  /// Read schema version from marker (null if missing/corrupt).
  int? readSchemaVersion() {
    final raw = _fs.readText(_paths.join(rootPath, 'schema.json'));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map && json['schemaVersion'] is num) {
        return (json['schemaVersion'] as num).toInt();
      }
    } on Object {
      return null;
    }
    return null;
  }

  /// Whether the store looks corrupted / incompatible.
  bool get needsRebuild {
    if (!_fs.directoryExists(rootPath)) return false;
    final v = readSchemaVersion();
    if (v == null) return true;
    return v > SchemaVersions.cache || v < 1;
  }

  /// Status summary.
  Map<String, Object?> status() {
    ensureLayout();
    final cacheFiles = _fs.listDirectory(cacheDir);
    final recoveryFiles = _fs.listDirectory(recoveryDir);
    final logFiles = _fs.listDirectory(logsDir);
    return {
      'root': rootPath,
      'schemaVersion': readSchemaVersion(),
      'expectedSchemaVersion': SchemaVersions.cache,
      'needsRebuild': needsRebuild,
      'cacheEntries': cacheFiles.length,
      'recoveryEntries': recoveryFiles.length,
      'logEntries': logFiles.length,
    };
  }

  /// Delete cache contents (keeps layout).
  Map<String, Object?> clean({bool includeLogs = false}) {
    ensureLayout();
    var removed = 0;
    for (final e in _fs.listDirectory(cacheDir)) {
      try {
        e.deleteSync(recursive: true);
        removed++;
      } on Object {
        // skip
      }
    }
    if (includeLogs) {
      for (final e in _fs.listDirectory(logsDir)) {
        try {
          e.deleteSync(recursive: true);
          removed++;
        } on Object {
          // skip
        }
      }
    }
    return {'removed': removed, 'root': rootPath};
  }

  /// Repair: rebuild schema marker and prune corrupt JSON files.
  Map<String, Object?> repair() {
    ensureLayout();
    final marker = _paths.join(rootPath, 'schema.json');
    final body = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': SchemaVersions.cache,
      'repairedAt': DateTime.now().toUtc().toIso8601String(),
    });
    _fs.writeText(marker, '$body\n');

    var pruned = 0;
    for (final e in _fs.listDirectory(cacheDir)) {
      if (!e.path.endsWith('.json')) continue;
      final text = _fs.readText(e.path);
      if (text == null) continue;
      try {
        jsonDecode(text);
      } on Object {
        _fs.deleteFile(e.path);
        pruned++;
      }
    }
    return {
      'schemaVersion': SchemaVersions.cache,
      'prunedCorrupt': pruned,
      'root': rootPath,
    };
  }

  /// Write a JSON cache entry with checksum.
  Future<void> putJson(String key, Map<String, Object?> value) async {
    ensureLayout();
    final safe = _safeKey(key);
    final payload = {
      'schemaVersion': SchemaVersions.cache,
      'key': key,
      'checksum': _checksum(jsonEncode(value)),
      'value': value,
      'writtenAt': DateTime.now().toUtc().toIso8601String(),
    };
    final path = _paths.join(cacheDir, '$safe.json');
    await _fs.writeTextAtomic(
      path,
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  /// Read a JSON cache entry; null if missing/corrupt checksum.
  Map<String, Object?>? getJson(String key) {
    final safe = _safeKey(key);
    final path = _paths.join(cacheDir, '$safe.json');
    final raw = _fs.readText(path);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final value = json['value'];
      final checksum = json['checksum']?.toString();
      if (value is! Map) return null;
      final map = Map<String, Object?>.from(value);
      if (checksum != null && checksum != _checksum(jsonEncode(map))) {
        return null;
      }
      return map;
    } on Object {
      return null;
    }
  }

  /// Append a recovery journal entry.
  Future<void> appendRecovery(Map<String, Object?> entry) async {
    ensureLayout();
    final name =
        'journal_${DateTime.now().toUtc().millisecondsSinceEpoch}.json';
    final path = _paths.join(recoveryDir, name);
    final payload = {
      'schemaVersion': SchemaVersions.recovery,
      ...entry,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    await _fs.writeTextAtomic(
      path,
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  /// List recovery journal entries (newest first).
  List<Map<String, Object?>> listRecovery({int limit = 20}) {
    if (!_fs.directoryExists(recoveryDir)) return const [];
    final files = _fs
        .listDirectory(recoveryDir)
        .where((e) => e.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    final out = <Map<String, Object?>>[];
    for (final f in files.take(limit)) {
      final raw = _fs.readText(f.path);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw);
        if (json is Map) {
          out.add(Map<String, Object?>.from(json));
        }
      } on Object {
        continue;
      }
    }
    return out;
  }

  /// Clear recovery journals after successful recover.
  int clearRecovery() {
    var n = 0;
    for (final e in _fs.listDirectory(recoveryDir)) {
      try {
        e.deleteSync(recursive: true);
        n++;
      } on Object {
        // skip
      }
    }
    return n;
  }

  /// Append a log line.
  void appendLog(String line) {
    ensureLayout();
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final path = _paths.join(logsDir, '$day.log');
    final existing = _fs.readText(path) ?? '';
    _fs.writeText(
      path,
      '$existing${DateTime.now().toUtc().toIso8601String()} $line\n',
    );
  }

  String _safeKey(String key) {
    final digest = _checksum(key);
    final base = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final trimmed = base.length > 40 ? base.substring(0, 40) : base;
    return '${trimmed}_$digest';
  }

  /// Stable non-cryptographic checksum (FNV-1a 64-bit hex).
  String _checksum(String input) {
    var hash = 0xcbf29ce484222325;
    for (final c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
