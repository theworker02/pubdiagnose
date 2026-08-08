import 'package:path/path.dart' as p;

import '../cache/cache_store.dart';
import '../config/pubdoctor_config.dart';
import '../diagnostics/health_analyzer.dart';
import '../distributed/execution_coordinator.dart';
import '../distributed/execution_worker.dart';
import '../distributed/scheduler.dart';
import '../distributed/worker_capability.dart';
import '../environment_snapshot/environment_snapshot.dart';
import '../features/feature_maturity.dart';
import '../features/feature_registry.dart';
import '../healing/healing_engine.dart';
import '../impact/impact_engine.dart';
import '../impact/impact_report.dart';
import '../incremental/incremental_engine.dart';
import '../integrity/integrity_engine.dart';
import '../intelligence/snapshot_store.dart';
import '../maintenance/maintenance_controller.dart';
import '../maintenance/maintenance_plan.dart';
import '../metadata/package_repository.dart';
import '../migration_knowledge/migration_catalog.dart';
import '../migrations/migration_planner.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../observatory/ecosystem_observer.dart';
import '../platform/platform_service.dart';
import '../plugins/plugin_registry.dart';
import '../policy/policy_engine.dart';
import '../policy/policy_result.dart';
import '../recommendations/upgrade_analyzer.dart';
import '../remediation/fix_applier.dart';
import '../remediation/fix_plan.dart';
import '../repair/repair_engine.dart';
import '../repair_contracts/proof_result.dart';
import '../repair_contracts/repair_contract.dart';
import '../resilience/analyzer_pipeline.dart';
import '../resilience/builtin_modules.dart';
import '../resilience/doctor_report.dart';
import '../resilience/recovery_service.dart';
import '../risk/risk_engine.dart';
import '../risk/risk_report.dart';
import '../runtime/runtime_profile.dart';
import '../security/supply_chain_analyzer.dart';
import '../source/source_workspace.dart';
import '../workspace/workspace_loader.dart';
import 'capability_registry.dart';
import 'execution_context.dart';
import 'lifecycle.dart';
import 'operation_result.dart';
import 'pubdoctor_options.dart';
import 'service_registry.dart';

/// Unified analysis kernel — CLI and library entry share this wiring.
class PubDoctorKernel {
  PubDoctorKernel._({
    required this.execution,
    required this.options,
    required this.lifecycle,
    required this.features,
    required this.plugins,
    required WorkspaceLoader loader,
  }) : _loader = loader;

  /// Create and initialize a kernel for [workspacePath].
  static Future<PubDoctorKernel> create({
    String workspacePath = '.',
    PubDoctorOptions options = PubDoctorOptions.defaults,
  }) async {
    final lifecycle = LifecycleController()
      ..transition(KernelLifecycle.starting);

    final platform = options.platform ??
        PlatformService.detect(
          allowProcess: options.allowProcess,
          forceColor: options.forceColor,
          forceInteractive: options.forceInteractive,
        );

    final normalized = p.normalize(p.absolute(workspacePath));
    final cache = CacheStore.forWorkspace(
      normalized,
      fs: platform.fs,
      paths: platform.paths,
    );
    try {
      cache.ensureLayout();
    } on Object {
      // Read-only FS — continue without durable cache.
    }

    final capabilities = CapabilityRegistry.fromPlatform(
      filesystemRead: true,
      filesystemWrite: _canWrite(platform, normalized),
      processExecute: options.allowProcess,
      networkHttp: options.networkEnabled,
      terminalColor: platform.terminal.supportsAnsi,
      terminalInteractive: platform.terminal.isInteractive,
      symlink: true,
      flutterAvailable: platform.flutterAvailable,
      gitAvailable: platform.gitAvailable,
    );

    final repository =
        options.repository ?? PubDevRepository(timeout: options.httpTimeout);

    final services = ServiceRegistry()
      ..register(platform)
      ..register(cache)
      ..register<PackageRepository>(repository);

    PubDoctorConfig config;
    try {
      config = ConfigLoader.load(normalized);
    } on Object {
      config = PubDoctorConfig.defaults;
    }

    final cancellation = CancellationToken();
    final execution = ExecutionContext(
      workspacePath: normalized,
      platform: platform,
      capabilities: capabilities,
      services: services,
      config: config,
      cache: cache,
      repository: repository,
      cancellation: cancellation,
      offline: options.offline || !options.networkEnabled,
    );

    final loader = WorkspaceLoader(enrichFromCache: options.enrichFromCache);
    final features = FeatureRegistry.builtins();
    final plugins = PluginRegistry()..registerBuiltins(features);

    final kernel = PubDoctorKernel._(
      execution: execution,
      options: options,
      lifecycle: lifecycle,
      features: features,
      plugins: plugins,
      loader: loader,
    );

    lifecycle
      ..onDispose(() async {
        if (repository is PubDevRepository) {
          repository.close();
        }
      })
      ..transition(KernelLifecycle.ready);

    return kernel;
  }

  /// Shared execution context.
  final ExecutionContext execution;

  /// Construction options.
  final PubDoctorOptions options;

  /// Lifecycle controller.
  final LifecycleController lifecycle;

  /// Feature registry.
  final FeatureRegistry features;

  /// Plugin registry.
  final PluginRegistry plugins;

  final WorkspaceLoader _loader;

  /// Load the workspace.
  Future<OperationResult<PubWorkspace>> loadWorkspace() async {
    try {
      execution.checkpoint();
      final ws = await _loader.load(execution.workspacePath);
      return OperationResult.ok(ws);
    } on Object catch (e) {
      return OperationResult.fail(
        e.toString(),
        code: 'PD0001',
        cause: e,
      );
    }
  }

  /// Unified health check via fault-isolated pipeline + health rollup.
  Future<OperationResult<HealthReport>> check({
    bool? offline,
    int? workers,
  }) async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    final workspace = loaded.valueOrNull!;
    final skipNet = offline ?? execution.offline || options.minimal;

    try {
      final modules = <AnalyzerModule>[
        ...BuiltinModules.local(),
        if (!options.minimal) ...plugins.extraModules,
        if (!skipNet &&
            !options.minimal &&
            execution.capabilities.has(PubDoctorCapability.networkHttp))
          BuiltinModules.outdated(),
      ];
      // Run pipeline for fault isolation / soft diagnostics; health report
      // remains the stable public shape via HealthAnalyzer.
      final pipelineResult =
          await AnalyzerPipeline(modules).run(execution, workspace);
      for (final d in pipelineResult.diagnostics) {
        if (d.code == 'PD0009' || d.code == 'PD0008') {
          execution.reportSoft(d);
        }
      }

      final report = skipNet
          ? HealthAnalyzer(workspace: workspace).analyze()
          : await HealthAnalyzer.analyzeWithOutdated(
              workspace: workspace,
              upgradeAnalyzer: UpgradeAnalyzer(
                workspace: workspace,
                repository: execution.repository,
              ),
            );

      final soft = execution.softDiagnostics;
      final merged =
          soft.isEmpty ? report.diagnostics : [...report.diagnostics, ...soft];

      // Optional distributed worker fan-out for independent slices.
      final workerCount = workers ?? options.workers;
      if (workerCount != null && workerCount > 1 && !options.minimal) {
        await _runDistributedCheckSlice(workspace, workerCount);
      }

      final adjusted = HealthReport(
        projectName: report.projectName,
        status: report.status,
        directDependencyCount: report.directDependencyCount,
        devDependencyCount: report.devDependencyCount,
        transitiveDependencyCount: report.transitiveDependencyCount,
        overrideCount: report.overrideCount,
        outdatedCount: report.outdatedCount,
        constrainedUpgradeCount: report.constrainedUpgradeCount,
        conflictCount: report.conflictCount,
        hasLockfile: report.hasLockfile,
        summary: report.summary,
        diagnostics: execution.config.apply(merged),
        outdated: report.outdated,
      );
      return OperationResult.ok(adjusted);
    } on Object catch (e) {
      return OperationResult.fail(
        'check failed: $e',
        code: 'PD0008',
        cause: e,
        retryable: true,
      );
    }
  }

  Future<void> _runDistributedCheckSlice(
    PubWorkspace workspace,
    int workerCount,
  ) async {
    final dartVer = execution.platform.info.operatingSystemVersion;
    final pool = LocalWorkerPool(
      workerCount: workerCount,
      capabilityTemplate: WorkerCapability.local(
        sessionId: 'local',
        dartVersion: dartVer,
        os: execution.platform.info.osName,
        architecture: execution.platform.info.architectureHint,
      ),
    );
    final workers = pool.createWorkers();
    final coordinator = ExecutionCoordinator(
      transports: [for (final w in workers) w.asTransport()],
    );
    final names = [
      for (final d in workspace.pubspec.dependencies) d.name,
    ];
    final units = WorkScheduler.planCheckUnits(
      workspaceFingerprint: workspace.pubspec.name,
      packageNames: names,
    );
    try {
      await coordinator.run(units);
    } finally {
      await coordinator.close();
    }
  }

  /// Propose fixes.
  Future<OperationResult<FixPlan>> planFixes({
    String? code,
    String? package,
    bool safeOnly = false,
  }) async {
    final loaded = await loadWorkspace();
    return loaded.when(
      ok: (ws) => OperationResult.ok(
        FixApplier(ws).propose(
          code: code,
          package: package,
          safeOnly: safeOnly,
        ),
      ),
      fail: (f) => OperationResult.fail(
        f.message,
        code: f.code,
        cause: f.cause,
      ),
    );
  }

  /// Recover interrupted mutations / cache.
  Future<OperationResult<Map<String, Object?>>> recover() async {
    try {
      final service = RecoveryService(
        cache: execution.cache,
        fs: execution.platform.fs,
        paths: execution.platform.paths,
        workspacePath: execution.workspacePath,
      );
      return OperationResult.ok(await service.recover());
    } on Object catch (e) {
      return OperationResult.fail('recover failed: $e', cause: e);
    }
  }

  /// Cache status / clean / repair.
  OperationResult<Map<String, Object?>> cacheCommand(String action) {
    try {
      final store = execution.cache;
      return OperationResult.ok(switch (action) {
        'clean' => store.clean(),
        'repair' => store.repair(),
        _ => store.status(),
      });
    } on Object catch (e) {
      return OperationResult.fail('cache $action failed: $e', cause: e);
    }
  }

  /// Sanitized doctor report.
  Map<String, Object?> doctorReport({
    Object? error,
    StackTrace? stackTrace,
    bool includeSource = false,
  }) {
    return DoctorReportBuilder(
      platform: execution.platform,
      context: execution,
      includeSource: includeSource,
    ).build(error: error, stackTrace: stackTrace);
  }

  /// Machine inspection payload for IDEs/CI.
  Future<Map<String, Object?>> inspect() async {
    final loaded = await loadWorkspace();
    final workspaceJson = loaded.when(
      ok: (ws) => {
        'name': ws.pubspec.name,
        'hasLockfile': ws.hasLockfile,
        'directDependencies': ws.pubspec.dependencies.length,
        'devDependencies': ws.pubspec.devDependencies.length,
        'overrides': ws.pubspec.dependencyOverrides.length,
      },
      fail: (f) => {
        'error': f.message,
        'code': f.code,
      },
    );

    return {
      'schemaVersion': 1,
      'tool': 'pubdoctor',
      'workspacePath': execution.workspacePath,
      'workspace': workspaceJson,
      'capabilities': execution.capabilities.toJson(),
      'platform': execution.platform.toJson(),
      'features': features.ids,
      'featureMaturity': FeatureMaturityCatalog.toJsonList(),
      'plugins': plugins.ids,
      'config': execution.config.toJson(),
      'cache': execution.cache.status(),
      'options': {
        'offline': execution.offline,
        'enrichFromCache': options.enrichFromCache,
      },
    };
  }

  /// Dependency risk intelligence.
  Future<OperationResult<RiskReport>> risk({
    String? package,
    bool? offline,
  }) async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    final workspace = loaded.valueOrNull!;
    final skipNet = offline ?? execution.offline;
    try {
      final engine = RiskEngine(
        workspace: workspace,
        repository:
            skipNet ? const OfflinePackageRepository() : execution.repository,
        largeWorkspace: execution.config.largeWorkspace,
      );
      final report = await engine.analyze(package: package, offline: skipNet);
      final diagnostics = execution.config.apply(report.diagnostics);
      return OperationResult.ok(
        RiskReport(
          projectName: report.projectName,
          packages: report.packages,
          signals: report.signals,
          concentration: report.concentration,
          diagnostics: diagnostics,
          focusPackage: report.focusPackage,
        ),
      );
    } on Object catch (e) {
      return OperationResult.fail('risk failed: $e', cause: e, retryable: true);
    }
  }

  /// Policy check using configured rules.
  Future<OperationResult<PolicyResult>> policyCheck() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    try {
      final engine = PolicyEngine(
        workspace: loaded.valueOrNull!,
        rules: execution.config.policies,
        sourcePath: execution.config.sourcePath,
      );
      final result = await engine.check();
      return OperationResult.ok(
        PolicyResult(
          findings: result.findings,
          rulesEvaluated: result.rulesEvaluated,
          sourcePath: result.sourcePath,
        ),
      );
    } on Object catch (e) {
      return OperationResult.fail('policy check failed: $e', cause: e);
    }
  }

  /// Change impact analysis.
  Future<OperationResult<ImpactReport>> impact(
      ChangeSimulation simulation) async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    try {
      final engine = ImpactEngine(
        loaded.valueOrNull!,
        pathLimit: execution.config.largeWorkspace ? 8 : 16,
      );
      final report = switch (simulation.kind) {
        ChangeSimulationKind.upgradePackage => engine.upgradePackage(
            simulation.package!,
            simulation.version ?? 'latest',
          ),
        ChangeSimulationKind.removePackage =>
          engine.removePackage(simulation.package!),
        ChangeSimulationKind.upgradeAll => engine.upgradeAll(),
      };
      return OperationResult.ok(report);
    } on Object catch (e) {
      return OperationResult.fail('impact failed: $e', cause: e);
    }
  }

  /// Migration planner bound to this workspace/cache.
  Future<OperationResult<MigrationPlanner>> migrationPlanner() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    return OperationResult.ok(
      MigrationPlanner(
        workspace: loaded.valueOrNull!,
        repository: execution.repository,
        cache: execution.cache,
      ),
    );
  }

  /// Snapshot store.
  SnapshotStore snapshotStore() => SnapshotStore(execution.cache);

  /// Incremental / profile engine.
  Future<OperationResult<IncrementalEngine>> incremental() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    return OperationResult.ok(
      IncrementalEngine(
        workspace: loaded.valueOrNull!,
        fs: execution.platform.fs,
        paths: execution.platform.paths,
        largeWorkspace: execution.config.largeWorkspace,
      ),
    );
  }

  /// Internal health / healing context.
  HealingEngine healingEngine() {
    return HealingEngine(
      context: HealingContext(
        execution: execution,
        cache: execution.cache,
      ),
    );
  }

  /// Source check.
  Future<OperationResult<List<SourceDiagnostic>>> sourceCheck() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    try {
      final diags = SourceChecker(loaded.valueOrNull!).check();
      return OperationResult.ok(diags);
    } on Object catch (e) {
      return OperationResult.fail('source check failed: $e', cause: e);
    }
  }

  /// Repair engine for workspace.
  Future<OperationResult<RepairEngine>> repairEngine() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    return OperationResult.ok(
      RepairEngine(
        workspace: loaded.valueOrNull!,
        fs: execution.platform.fs,
        paths: execution.platform.paths,
        allowProcess: options.allowProcess,
      ),
    );
  }

  /// Integrity engine.
  Future<OperationResult<IntegrityEngine>> integrity() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    return OperationResult.ok(
      IntegrityEngine(
        workspace: loaded.valueOrNull!,
        fs: execution.platform.fs,
        paths: execution.platform.paths,
      ),
    );
  }

  /// Environment doctor.
  EnvironmentReport environmentReport({
    bool portable = false,
    bool minimal = false,
  }) {
    return EnvironmentReport.fromPlatform(
      execution.platform,
      portable: portable,
      offline: execution.offline,
      writable: execution.capabilities.has(PubDoctorCapability.filesystemWrite),
      minimal: minimal || options.minimal,
    );
  }

  /// Capture sanitized environment snapshot.
  Future<OperationResult<EnvironmentSnapshot>> environmentSnapshot() async {
    final loaded = await loadWorkspace();
    final workspace = loaded.valueOrNull;
    try {
      final snap = EnvironmentSnapshotEngine.capture(
        platform: execution.platform,
        capabilities: execution.capabilities,
        workspace: workspace,
        pubdoctorCachePresent: true,
      );
      return OperationResult.ok(snap);
    } on Object catch (e) {
      return OperationResult.fail('environment snapshot failed: $e', cause: e);
    }
  }

  /// Migration knowledge catalog.
  MigrationCatalog migrationCatalog() {
    final catalog = MigrationCatalog();
    // Optional packs beside the process CWD / package root.
    try {
      catalog.loadPacks(
        'migration_packs',
        execution.platform.fs,
        execution.platform.paths,
      );
    } on Object {
      // Packs are optional.
    }
    return catalog;
  }

  /// Ecosystem observer.
  EcosystemObserver ecosystemObserver({bool? offline}) {
    final skip = offline ?? execution.offline || options.minimal;
    return EcosystemObserver(
      offline: skip,
      cache: EcosystemCache(
        rootPath: execution.cache.rootPath,
        fs: execution.platform.fs,
        paths: execution.platform.paths,
      ),
      fetchMetadata: skip
          ? null
          : (package) async {
              final meta = await execution.repository.getPackage(package);
              return {
                'latest': meta.latest?.toString(),
                'discontinued': meta.isDiscontinued,
                if (meta.replacedBy != null) 'replacedBy': meta.replacedBy,
              };
            },
    );
  }

  /// Supply-chain security analysis.
  Future<OperationResult<List<Diagnostic>>> securityAnalyze() async {
    final loaded = await loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      return OperationResult.fail(
        loaded.message,
        code: loaded.code,
        cause: loaded.cause,
      );
    }
    try {
      final analyzer = SupplyChainAnalyzer(
        workspace: loaded.valueOrNull!,
        policy: execution.config.security,
      );
      return OperationResult.ok(execution.config.apply(analyzer.analyze()));
    } on Object catch (e) {
      return OperationResult.fail('security analyze failed: $e', cause: e);
    }
  }

  /// Issue a repair certificate for a planned/applied repair.
  RepairCertificate issueRepairCertificate({
    required String issue,
    required String repair,
    required RepairContract contract,
    required Map<String, Object?> preState,
    required Map<String, Object?> postState,
    List<String> negativeFindings = const [],
    String outcome = 'success',
  }) {
    final proof = ContractValidator().validate(
      contract: contract,
      preState: preState,
      postState: postState,
      negativeFindings: negativeFindings,
    );
    return RepairCertificate(
      issue: issue,
      repair: repair,
      contract: contract,
      preState: preState,
      postState: postState,
      proof: proof,
      outcome: proof.ok ? outcome : 'failed',
    );
  }

  /// Maintenance controller bound to this kernel.
  MaintenanceController maintenanceController() => MaintenanceController();

  /// Build + optionally run a maintenance cycle.
  Future<OperationResult<MaintenanceResult>> maintain({
    required MaintenancePolicy policy,
  }) async {
    try {
      final health = await check(offline: true);
      final healthReport = health.valueOrNull;
      final security = await securityAnalyze();
      final source = await sourceCheck();
      final healing = await healingEngine().healthReport();
      final pubdoctorHealthy =
          healing.values.every((v) => v.toString() == 'healthy');

      final sourceDiags = source.valueOrNull ?? const <SourceDiagnostic>[];
      final securityDiags = security.valueOrNull ?? const <Diagnostic>[];
      final controller = maintenanceController();
      final plan = controller.plan(
        health: healthReport,
        security: securityDiags,
        source: [
          for (final d in sourceDiags)
            Diagnostic(
              code: d.code,
              title: d.code,
              message: d.message,
              severity: DiagnosticSeverity.warning,
              package: d.package,
            ),
        ],
        pubdoctorHealthy: pubdoctorHealthy,
      );
      final codes = <String>{
        for (final d in healthReport?.diagnostics ?? const <Diagnostic>[])
          d.code,
        for (final d in securityDiags) d.code,
      };
      final result = controller.run(
        policy: policy,
        plan: plan,
        currentDiagnosticCodes: codes,
      );
      return OperationResult.ok(result);
    } on Object catch (e) {
      return OperationResult.fail('maintain failed: $e', cause: e);
    }
  }

  /// Dispose resources.
  Future<void> close() => lifecycle.dispose();

  static bool _canWrite(PlatformService platform, String path) {
    try {
      final probe = platform.paths.join(
        path,
        '.dart_tool',
        'pubdoctor_write_probe',
      );
      platform.fs.createDirectory(platform.paths.dirname(probe));
      platform.fs.writeText(probe, 'ok');
      platform.fs.deleteFile(probe);
      return true;
    } on Object {
      return false;
    }
  }
}
