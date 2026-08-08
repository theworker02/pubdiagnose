import 'work_result.dart';
import 'work_unit.dart';
import 'worker_capability.dart';

/// Abstract transport between coordinator and workers.
abstract class WorkerTransport {
  /// Advertise / handshake.
  Future<WorkerCapability> handshake();

  /// Submit a unit and await a result.
  Future<WorkResult> submit(WorkUnit unit);

  /// Close the transport.
  Future<void> close();
}

/// In-process transport that invokes a handler synchronously.
class LocalTransport implements WorkerTransport {
  /// Creates a local transport.
  LocalTransport({
    required this.capability,
    required Future<WorkResult> Function(WorkUnit unit) handler,
  }) : _handler = handler;

  /// Advertised capability.
  final WorkerCapability capability;

  final Future<WorkResult> Function(WorkUnit unit) _handler;

  @override
  Future<WorkerCapability> handshake() async => capability;

  @override
  Future<WorkResult> submit(WorkUnit unit) => _handler(unit);

  @override
  Future<void> close() async {}
}

/// Versioned remote protocol envelope (design + serialization).
///
/// Wire format is JSON over an opaque channel (HTTP, SSH stdio, etc.).
/// This class does not open sockets; it defines the message shapes.
class RemoteProtocolMessage {
  /// Creates a protocol message.
  const RemoteProtocolMessage({
    required this.type,
    required this.protocolVersion,
    required this.body,
  });

  /// Message type: handshake | work | result | error.
  final String type;

  /// Protocol version.
  final int protocolVersion;

  /// Body payload.
  final Map<String, Object?> body;

  /// JSON.
  Map<String, Object?> toJson() => {
        'type': type,
        'protocolVersion': protocolVersion,
        'body': body,
      };

  /// Parse.
  factory RemoteProtocolMessage.fromJson(Map<String, Object?> json) {
    return RemoteProtocolMessage(
      type: json['type']! as String,
      protocolVersion: (json['protocolVersion'] as num).toInt(),
      body: Map<String, Object?>.from(
        (json['body'] as Map).cast<String, Object?>(),
      ),
    );
  }

  /// Whether the message is acceptable for [expectedVersion].
  bool isCompatible(int expectedVersion) =>
      protocolVersion == expectedVersion &&
      const {'handshake', 'work', 'result', 'error'}.contains(type);
}
