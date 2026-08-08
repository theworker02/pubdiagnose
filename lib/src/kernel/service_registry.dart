/// Explicit dependency injection registry (typed, not a service-locator dump).
class ServiceRegistry {
  final Map<Type, Object> _services = {};

  /// Register [service] under its runtime type (or [asType]).
  void register<T extends Object>(T service, {Type? asType}) {
    _services[asType ?? T] = service;
  }

  /// Resolve [T], or throw if missing.
  T get<T extends Object>() {
    final value = _services[T];
    if (value is T) return value;
    throw StateError('Service not registered: $T');
  }

  /// Resolve [T] if present.
  T? maybeGet<T extends Object>() {
    final value = _services[T];
    return value is T ? value : null;
  }

  /// Whether [T] is registered.
  bool has<T extends Object>() => _services.containsKey(T);

  /// Registered types (for diagnostics).
  List<String> get registeredTypes =>
      [for (final t in _services.keys) t.toString()]..sort();
}
