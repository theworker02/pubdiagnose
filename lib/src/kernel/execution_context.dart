import '../cache/cache_store.dart';
import '../config/pubdoctor_config.dart';
import '../metadata/package_repository.dart';
import '../models/diagnostics.dart';
import '../platform/platform_service.dart';
import 'capability_registry.dart';
import 'lifecycle.dart';
import 'service_registry.dart';

/// Shared execution context passed across subsystems.
class ExecutionContext {
  /// Creates an execution context.
  ExecutionContext({
    required this.workspacePath,
    required this.platform,
    required this.capabilities,
    required this.services,
    required this.config,
    required this.cache,
    required this.repository,
    required this.cancellation,
    this.offline = false,
  });

  /// Absolute or normalized workspace path.
  final String workspacePath;

  /// Platform services.
  final PlatformService platform;

  /// Capability registry.
  final CapabilityRegistry capabilities;

  /// Explicit DI registry.
  final ServiceRegistry services;

  /// Loaded config.
  final PubDoctorConfig config;

  /// On-disk cache / state under `.dart_tool/pubdoctor`.
  final CacheStore cache;

  /// Package metadata repository.
  final PackageRepository repository;

  /// Cancellation token for this session.
  final CancellationToken cancellation;

  /// Force offline (no network).
  final bool offline;

  /// Diagnostic accumulator for soft failures.
  final List<Diagnostic> softDiagnostics = [];

  /// Record a non-fatal diagnostic.
  void reportSoft(Diagnostic diagnostic) => softDiagnostics.add(diagnostic);

  /// Throw if cancelled.
  void checkpoint() => cancellation.throwIfCancelled();
}
