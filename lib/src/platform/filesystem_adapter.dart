import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'path_adapter.dart';

/// Filesystem operations with atomic writes and graceful degradation.
class FilesystemAdapter {
  /// Creates a filesystem adapter.
  FilesystemAdapter(this.paths);

  /// Path helpers.
  final PathAdapter paths;

  /// Whether [path] exists as a file.
  bool fileExists(String path) => File(path).existsSync();

  /// Whether [path] exists as a directory.
  bool directoryExists(String path) => Directory(path).existsSync();

  /// Whether [path] exists (file, dir, or link).
  bool exists(String path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  /// Read text file; returns null if missing/unreadable.
  String? readText(String path, {Encoding encoding = utf8}) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsStringSync(encoding: encoding);
    } on Object {
      return null;
    }
  }

  /// Read bytes; returns null if missing/unreadable.
  Uint8List? readBytes(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsBytesSync();
    } on Object {
      return null;
    }
  }

  /// Write text (non-atomic). Prefer [writeTextAtomic] for mutations.
  void writeText(String path, String contents, {Encoding encoding = utf8}) {
    File(path).writeAsStringSync(contents, encoding: encoding, flush: true);
  }

  /// Atomic write via temp sibling + rename (best-effort on Windows).
  Future<void> writeTextAtomic(
    String path,
    String contents, {
    Encoding encoding = utf8,
  }) async {
    final dir = Directory(paths.dirname(path));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final tmp = File(
      paths.join(
        paths.dirname(path),
        '.${paths.basename(path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await tmp.writeAsString(contents, encoding: encoding, flush: true);
      if (File(path).existsSync()) {
        try {
          await File(path).delete();
        } on Object {
          // Fall through to rename overwrite attempts.
        }
      }
      await tmp.rename(path);
    } on Object {
      // Windows rename-over can fail; copy then delete.
      try {
        await tmp.copy(path);
        if (tmp.existsSync()) await tmp.delete();
      } on Object {
        if (tmp.existsSync()) {
          try {
            await tmp.delete();
          } on Object {
            // best-effort cleanup
          }
        }
        rethrow;
      }
    }
  }

  /// Create directory recursively.
  void createDirectory(String path) {
    Directory(path).createSync(recursive: true);
  }

  /// Delete file if present.
  bool deleteFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      file.deleteSync();
      return true;
    } on Object {
      return false;
    }
  }

  /// Delete directory recursively if present.
  bool deleteDirectory(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    try {
      dir.deleteSync(recursive: true);
      return true;
    } on Object {
      return false;
    }
  }

  /// List directory children (empty if missing/unreadable).
  List<FileSystemEntity> listDirectory(String path, {bool recursive = false}) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    try {
      return dir.listSync(recursive: recursive, followLinks: false);
    } on Object {
      return const [];
    }
  }

  /// Resolve symlink / junction target; null if not a link or unsupported.
  String? resolveLink(String path) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type != FileSystemEntityType.link) return null;
      return Link(path).resolveSymbolicLinksSync();
    } on Object {
      return null;
    }
  }

  /// Whether [path] is a symlink or junction.
  bool isLink(String path) {
    try {
      return FileSystemEntity.typeSync(path, followLinks: false) ==
          FileSystemEntityType.link;
    } on Object {
      return false;
    }
  }

  /// System temp directory (never hard-codes `/tmp`).
  Directory systemTemp() => Directory.systemTemp;

  /// Create a unique temp subdirectory.
  Directory createTempDir([String prefix = 'pubdoctor_']) {
    return systemTemp().createTempSync(prefix);
  }
}
