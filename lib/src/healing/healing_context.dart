import '../cache/cache_store.dart';
import '../kernel/execution_context.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';

/// Context for healing operations.
class HealingContext {
  /// Creates a context.
  HealingContext({
    required this.execution,
    required this.cache,
    FilesystemAdapter? fs,
    PathAdapter? paths,
  })  : fs = fs ?? cache.fs,
        paths = paths ?? cache.paths;

  /// Execution context.
  final ExecutionContext execution;

  /// Cache store.
  final CacheStore cache;

  /// Filesystem.
  final FilesystemAdapter fs;

  /// Paths.
  final PathAdapter paths;

  /// Workspace path.
  String get workspacePath => execution.workspacePath;

  /// Healing root.
  String get healingDir => paths.join(cache.rootPath, 'healing');
}
