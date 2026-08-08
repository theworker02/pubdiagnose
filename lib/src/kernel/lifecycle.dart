import 'dart:async';

/// Cooperative cancellation token.
class CancellationToken {
  /// Creates a token.
  CancellationToken();

  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;
  Object? _reason;

  /// Whether cancellation was requested.
  bool get isCancelled => _cancelled;

  /// Optional reason.
  Object? get reason => _reason;

  /// Future that completes when cancelled.
  Future<void> get whenCancelled => _completer.future;

  /// Request cancellation.
  void cancel([Object? reason]) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Throw [CancellationException] if cancelled.
  void throwIfCancelled() {
    if (_cancelled) {
      throw CancellationException(reason);
    }
  }
}

/// Thrown when an operation observes cancellation.
class CancellationException implements Exception {
  /// Creates an exception.
  CancellationException([this.reason]);

  /// Optional reason.
  final Object? reason;

  @override
  String toString() =>
      reason == null ? 'Operation cancelled' : 'Operation cancelled: $reason';
}

/// Kernel lifecycle phases.
enum KernelLifecycle {
  /// Not yet created.
  uninitialized,

  /// Constructing services.
  starting,

  /// Ready for operations.
  ready,

  /// Shutting down / disposing.
  stopping,

  /// Fully disposed.
  disposed,
}

/// Tracks kernel lifecycle and registers dispose callbacks.
class LifecycleController {
  KernelLifecycle _phase = KernelLifecycle.uninitialized;
  final List<FutureOr<void> Function()> _disposeHooks = [];

  /// Current phase.
  KernelLifecycle get phase => _phase;

  /// Transition to [next].
  void transition(KernelLifecycle next) {
    _phase = next;
  }

  /// Register cleanup work.
  void onDispose(FutureOr<void> Function() hook) {
    _disposeHooks.add(hook);
  }

  /// Run dispose hooks and mark disposed.
  Future<void> dispose() async {
    _phase = KernelLifecycle.stopping;
    for (final hook in _disposeHooks.reversed) {
      try {
        await hook();
      } on Object {
        // Isolate dispose failures.
      }
    }
    _disposeHooks.clear();
    _phase = KernelLifecycle.disposed;
  }
}
