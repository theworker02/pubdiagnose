import '../cache/cache_store.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';

/// Recovers from interrupted mutations / partial writes.
class RecoveryService {
  /// Creates a recovery service.
  RecoveryService({
    required this.cache,
    required this.fs,
    required this.paths,
    required this.workspacePath,
  });

  /// Cache store.
  final CacheStore cache;

  /// Filesystem.
  final FilesystemAdapter fs;

  /// Paths.
  final PathAdapter paths;

  /// Workspace root.
  final String workspacePath;

  /// Scan and recover.
  Future<Map<String, Object?>> recover() async {
    cache.ensureLayout();
    final actions = <String>[];

    // Restore pubspec from backup if present and primary missing/corrupt.
    final backup = paths.join(workspacePath, '.pubdoctor_pubspec.bak');
    final pubspec = paths.join(workspacePath, 'pubspec.yaml');
    if (fs.fileExists(backup)) {
      if (!fs.fileExists(pubspec)) {
        final text = fs.readText(backup);
        if (text != null) {
          await fs.writeTextAtomic(pubspec, text);
          actions.add('Restored pubspec.yaml from .pubdoctor_pubspec.bak');
        }
      }
      fs.deleteFile(backup);
      actions.add('Removed stale .pubdoctor_pubspec.bak');
    }

    // Remove partial temp writes in project root.
    for (final e in fs.listDirectory(workspacePath)) {
      final name = paths.basename(e.path);
      if (name.startsWith('.pubspec.yaml.') && name.endsWith('.tmp')) {
        fs.deleteFile(e.path);
        actions.add('Removed partial write $name');
      }
      if (name.startsWith('.pubdoctor_') && name.endsWith('.tmp')) {
        fs.deleteFile(e.path);
        actions.add('Removed temp $name');
      }
    }

    // Repair cache schema / corrupt entries.
    final repair = cache.repair();
    actions.add(
      'Cache repair pruned ${repair['prunedCorrupt']} corrupt entr'
      '${repair['prunedCorrupt'] == 1 ? 'y' : 'ies'}',
    );

    final cleared = cache.clearRecovery();
    if (cleared > 0) {
      actions.add('Cleared $cleared recovery journal entr'
          '${cleared == 1 ? 'y' : 'ies'}');
    }

    await cache.appendRecovery({
      'action': 'recover',
      'actions': actions,
    });

    return {
      'ok': true,
      'actions': actions,
      'cache': cache.status(),
    };
  }
}
