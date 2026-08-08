/// Capability flags for a remote analysis session.
class RemoteCapability {
  /// Creates capabilities.
  const RemoteCapability({
    this.canRead = true,
    this.canWrite = false,
    this.canExecute = false,
    this.canStream = true,
    this.maxBytes = 64 * 1024 * 1024,
  });

  /// Read files.
  final bool canRead;

  /// Write files.
  final bool canWrite;

  /// Execute processes remotely.
  final bool canExecute;

  /// Stream large trees without full materialization.
  final bool canStream;

  /// Soft memory / transfer budget in bytes.
  final int maxBytes;

  /// JSON.
  Map<String, Object?> toJson() => {
        'canRead': canRead,
        'canWrite': canWrite,
        'canExecute': canExecute,
        'canStream': canStream,
        'maxBytes': maxBytes,
      };
}

/// Abstract transport for remote workspaces (SSH, cloud IDE, container mount…).
abstract class RemoteTransport {
  /// Protocol / transport id.
  String get id;

  /// Open a session to [uri].
  Future<RemoteSession> open(String uri, {RemoteCapability? capability});
}

/// An open remote session.
class RemoteSession {
  /// Creates a session.
  RemoteSession({
    required this.id,
    required this.uri,
    required this.capability,
    required this.filesystem,
  });

  /// Session id.
  final String id;

  /// Remote URI.
  final String uri;

  /// Capabilities.
  final RemoteCapability capability;

  /// Filesystem abstraction.
  final RemoteFilesystem filesystem;

  /// Close the session.
  Future<void> close() async {}

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'uri': uri,
        'capability': capability.toJson(),
      };
}

/// Remote filesystem abstraction (not tied to SSH).
abstract class RemoteFilesystem {
  /// Whether [path] exists.
  Future<bool> exists(String path);

  /// Read text file.
  Future<String?> readText(String path);

  /// List relative paths under [directory], optionally streaming.
  Stream<String> list(String directory, {bool recursive = false});

  /// Soft memory budget remaining.
  int get remainingBudget;
}

/// In-memory / local-backed remote filesystem for tests and adapters.
class MemoryRemoteFilesystem implements RemoteFilesystem {
  /// Creates a filesystem with optional seed files.
  MemoryRemoteFilesystem({
    Map<String, String>? files,
    this.budgetBytes = 8 * 1024 * 1024,
  }) : _files = {...?files};

  final Map<String, String> _files;

  /// Soft budget.
  int budgetBytes;

  int _used = 0;

  @override
  int get remainingBudget => budgetBytes - _used;

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<String?> readText(String path) async {
    final text = _files[path];
    if (text != null) {
      _used += text.length;
      if (_used > budgetBytes) {
        throw StateError('Remote filesystem memory budget exceeded');
      }
    }
    return text;
  }

  @override
  Stream<String> list(String directory, {bool recursive = false}) async* {
    final normalized = directory == '.' || directory.isEmpty ? '' : directory;
    final prefix = normalized.isEmpty
        ? ''
        : (normalized.endsWith('/') ? normalized : '$normalized/');
    for (final key in _files.keys) {
      if (prefix.isEmpty) {
        // Root listing: yield top-level and nested paths.
        yield key;
      } else if (key == normalized || key.startsWith(prefix)) {
        yield key;
      } else {
        continue;
      }
      _used += key.length;
      if (_used > budgetBytes) {
        throw StateError('Remote filesystem memory budget exceeded');
      }
    }
  }

  /// Seed a file.
  void write(String path, String content) => _files[path] = content;
}

/// Local-folder transport used as a remote-shaped adapter.
class LocalFolderRemoteTransport implements RemoteTransport {
  /// Creates a transport.
  LocalFolderRemoteTransport(this._readFile);

  final Future<String?> Function(String root, String relative) _readFile;

  @override
  String get id => 'local-folder';

  @override
  Future<RemoteSession> open(
    String uri, {
    RemoteCapability? capability,
  }) async {
    final cap = capability ?? const RemoteCapability();
    final fs = _LazyRemoteFilesystem(uri, _readFile, cap.maxBytes);
    return RemoteSession(
      id: 'local-${uri.hashCode}',
      uri: uri,
      capability: cap,
      filesystem: fs,
    );
  }
}

class _LazyRemoteFilesystem implements RemoteFilesystem {
  _LazyRemoteFilesystem(this.root, this._readFile, this.budgetBytes);

  final String root;
  final Future<String?> Function(String root, String relative) _readFile;
  final int budgetBytes;
  int _used = 0;

  @override
  int get remainingBudget => budgetBytes - _used;

  @override
  Future<bool> exists(String path) async =>
      (await _readFile(root, path)) != null;

  @override
  Future<String?> readText(String path) async {
    final text = await _readFile(root, path);
    if (text != null) {
      _used += text.length;
      if (_used > budgetBytes) {
        throw StateError('Remote filesystem memory budget exceeded');
      }
    }
    return text;
  }

  @override
  Stream<String> list(String directory, {bool recursive = false}) async* {
    // Streaming hook: yield known essential files only (no full tree load).
    for (final name in [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml'
    ]) {
      final rel =
          directory.isEmpty || directory == '.' ? name : '$directory/$name';
      if (await exists(rel)) {
        yield rel;
        _used += rel.length;
      }
    }
  }
}

/// A workspace exposed through [RemoteFilesystem].
class RemoteWorkspace {
  /// Creates a remote workspace handle.
  RemoteWorkspace({
    required this.session,
    this.root = '.',
  });

  /// Session.
  final RemoteSession session;

  /// Root path within the remote FS.
  final String root;

  /// Load pubspec text without loading the entire tree.
  Future<String?> readPubspec() =>
      session.filesystem.readText(_join(root, 'pubspec.yaml'));

  /// Stream essential files (memory-conscious).
  Stream<String> streamEssentialFiles() =>
      session.filesystem.list(root, recursive: false);

  String _join(String a, String b) {
    if (a == '.' || a.isEmpty) return b;
    return '$a/$b';
  }

  /// JSON.
  Map<String, Object?> toJson() => {
        'session': session.toJson(),
        'root': root,
        'remainingBudget': session.filesystem.remainingBudget,
      };
}

/// Soft memory budgets for constrained runtimes.
class MemoryBudget {
  /// Creates a budget.
  const MemoryBudget({
    this.sourceIndexBytes = 32 * 1024 * 1024,
    this.metadataCacheBytes = 16 * 1024 * 1024,
    this.graphBytes = 16 * 1024 * 1024,
    this.snapshotRetention = 5,
  });

  /// Source indexing budget.
  final int sourceIndexBytes;

  /// Metadata cache budget.
  final int metadataCacheBytes;

  /// Graph expansion budget.
  final int graphBytes;

  /// Max retained snapshots.
  final int snapshotRetention;

  /// Minimal profile budgets.
  static const minimal = MemoryBudget(
    sourceIndexBytes: 4 * 1024 * 1024,
    metadataCacheBytes: 2 * 1024 * 1024,
    graphBytes: 4 * 1024 * 1024,
    snapshotRetention: 1,
  );

  /// JSON.
  Map<String, Object?> toJson() => {
        'sourceIndexBytes': sourceIndexBytes,
        'metadataCacheBytes': metadataCacheBytes,
        'graphBytes': graphBytes,
        'snapshotRetention': snapshotRetention,
      };
}
