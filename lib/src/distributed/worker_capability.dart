import 'work_unit.dart';

/// Advertised capabilities of a worker (local or remote).
class WorkerCapability {
  /// Creates a capability advertisement.
  const WorkerCapability({
    required this.sessionId,
    required this.protocolVersion,
    required this.dartVersion,
    required this.os,
    required this.architecture,
    this.kinds = const {},
    this.maxScope = TrustScope.metadataOnly,
    this.availableTools = const [],
    this.notes = const [],
  });

  /// Worker session identity.
  final String sessionId;

  /// Supported PubDoctor remote protocol version.
  final int protocolVersion;

  /// Dart SDK version string.
  final String dartVersion;

  /// OS name.
  final String os;

  /// CPU architecture hint.
  final String architecture;

  /// Supported work kinds.
  final Set<WorkUnitKind> kinds;

  /// Maximum trust scope this worker may accept.
  final TrustScope maxScope;

  /// Available tools (analyzer, flutter, git, …).
  final List<String> availableTools;

  /// Free-form notes.
  final List<String> notes;

  /// Whether this worker can execute [unit].
  bool canExecute(WorkUnit unit) {
    if (unit.protocolVersion > protocolVersion) return false;
    if (!kinds.contains(unit.kind)) return false;
    if (unit.scope.index > maxScope.index) return false;
    return true;
  }

  /// JSON.
  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'protocolVersion': protocolVersion,
        'dartVersion': dartVersion,
        'os': os,
        'architecture': architecture,
        'kinds': [for (final k in kinds) k.name]..sort(),
        'maxScope': maxScope.name,
        'availableTools': availableTools,
        if (notes.isNotEmpty) 'notes': notes,
      };

  /// Local default capabilities for this process.
  factory WorkerCapability.local({
    required String sessionId,
    required String dartVersion,
    required String os,
    required String architecture,
    TrustScope maxScope = TrustScope.fullWorkspace,
  }) {
    return WorkerCapability(
      sessionId: sessionId,
      protocolVersion: WorkUnit.protocolVersionV1,
      dartVersion: dartVersion,
      os: os,
      architecture: architecture,
      kinds: WorkUnitKind.values.toSet(),
      maxScope: maxScope,
      availableTools: const ['pubdoctor', 'dart'],
    );
  }
}
