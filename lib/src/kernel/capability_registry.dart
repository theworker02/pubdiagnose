/// Named capabilities that subsystems may require or optionally use.
enum PubDoctorCapability {
  /// Read files / directories.
  filesystemRead,

  /// Write files / directories.
  filesystemWrite,

  /// Spawn external processes.
  processExecute,

  /// HTTP network access.
  networkHttp,

  /// ANSI / color terminal output.
  terminalColor,

  /// Interactive prompts / progress.
  terminalInteractive,

  /// Symlink / junction resolution.
  symlink,

  /// Filesystem watcher (optional future).
  watcher,

  /// Flutter SDK present on host.
  flutterAvailable,

  /// Git present on host.
  gitAvailable,
}

/// Tracks which capabilities are available for this process.
class CapabilityRegistry {
  /// Creates a registry with an initial set.
  CapabilityRegistry([Iterable<PubDoctorCapability>? initial])
      : _enabled = {...?initial};

  /// Detect from a [PlatformService]-like snapshot.
  factory CapabilityRegistry.fromPlatform({
    required bool filesystemRead,
    required bool filesystemWrite,
    required bool processExecute,
    required bool networkHttp,
    required bool terminalColor,
    required bool terminalInteractive,
    required bool symlink,
    required bool flutterAvailable,
    required bool gitAvailable,
    bool watcher = false,
  }) {
    final caps = <PubDoctorCapability>{
      if (filesystemRead) PubDoctorCapability.filesystemRead,
      if (filesystemWrite) PubDoctorCapability.filesystemWrite,
      if (processExecute) PubDoctorCapability.processExecute,
      if (networkHttp) PubDoctorCapability.networkHttp,
      if (terminalColor) PubDoctorCapability.terminalColor,
      if (terminalInteractive) PubDoctorCapability.terminalInteractive,
      if (symlink) PubDoctorCapability.symlink,
      if (watcher) PubDoctorCapability.watcher,
      if (flutterAvailable) PubDoctorCapability.flutterAvailable,
      if (gitAvailable) PubDoctorCapability.gitAvailable,
    };
    return CapabilityRegistry(caps);
  }

  final Set<PubDoctorCapability> _enabled;

  /// Whether [capability] is available.
  bool has(PubDoctorCapability capability) => _enabled.contains(capability);

  /// All enabled capabilities.
  Set<PubDoctorCapability> get all => Set.unmodifiable(_enabled);

  /// Enable a capability.
  void enable(PubDoctorCapability capability) => _enabled.add(capability);

  /// Disable a capability (e.g. offline mode).
  void disable(PubDoctorCapability capability) => _enabled.remove(capability);

  /// Require [capability] or throw [StateError].
  void require(PubDoctorCapability capability) {
    if (!has(capability)) {
      throw StateError('Required capability unavailable: ${capability.name}');
    }
  }

  /// JSON list of capability names.
  List<String> toJson() => [
        for (final c in PubDoctorCapability.values)
          if (has(c)) c.name
      ]..sort();
}
