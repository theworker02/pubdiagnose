/// Dependency diagnostics and package-resolution analysis for Dart/pub.
///
/// **PubDiagnose** (`package:pubdiagnose`) — Diagnose your Dart dependencies.
/// CLI executable: `pubdoctor`. Prefer [PubDoctor.open] for programmatic use:
/// ```dart
/// final kernel = await PubDoctor.open('.');
/// final result = await kernel.check();
/// await kernel.close();
/// ```
library;

export 'src/analysis/import_scanner.dart';
export 'src/analysis/package_explainer.dart';
export 'src/cache/cache_store.dart';
export 'src/compatibility/deprecation.dart';
export 'src/compatibility/matrix.dart';
export 'src/config/baseline.dart';
export 'src/config/pubdoctor_config.dart';
export 'src/constraints/constraint_analyzer.dart';
export 'src/diagnostics/classification_analyzer.dart';
export 'src/diagnostics/diagnostic_catalog.dart';
export 'src/diagnostics/health_analyzer.dart';
export 'src/diagnostics/import_analyzer.dart';
export 'src/diagnostics/override_analyzer.dart';
export 'src/diagnostics/unused_analyzer.dart';
export 'src/features/feature_registry.dart';
export 'src/graph/dependency_graph.dart';
export 'src/kernel/capability_registry.dart';
export 'src/kernel/command_context.dart';
export 'src/kernel/execution_context.dart';
export 'src/kernel/lifecycle.dart';
export 'src/kernel/operation_result.dart';
export 'src/kernel/pubdoctor_kernel.dart';
export 'src/kernel/pubdoctor_options.dart';
export 'src/kernel/service_registry.dart';
export 'src/lockfile/lockfile_parser.dart';
export 'src/metadata/package_repository.dart';
export 'src/models/constraints.dart';
export 'src/models/dependency_spec.dart';
export 'src/models/diagnostics.dart';
export 'src/models/exceptions.dart';
export 'src/models/graph_models.dart';
export 'src/models/health.dart';
export 'src/models/lockfile.dart';
export 'src/models/metadata.dart';
export 'src/models/pubspec_document.dart';
export 'src/models/recommendations.dart';
export 'src/platform/environment_adapter.dart';
export 'src/platform/filesystem_adapter.dart';
export 'src/platform/path_adapter.dart';
export 'src/platform/platform_info.dart';
export 'src/platform/platform_service.dart';
export 'src/platform/process_adapter.dart';
export 'src/platform/terminal_adapter.dart';
export 'src/plugins/plugin_registry.dart';
export 'src/pubdoctor.dart';
export 'src/pubspec/pubspec_parser.dart';
export 'src/recommendations/recommendation_engine.dart';
export 'src/recommendations/sdk_analyzer.dart';
export 'src/recommendations/upgrade_analyzer.dart';
export 'src/remediation/fix_applier.dart';
export 'src/remediation/fix_plan.dart';
export 'src/remediation/fix_planner.dart';
export 'src/resilience/analyzer_pipeline.dart';
export 'src/resilience/doctor_report.dart';
export 'src/resilience/recovery_service.dart';
export 'src/serialization/schema_version.dart';
export 'src/version.dart';
export 'src/workspace/monorepo_analyzer.dart';
export 'src/workspace/pub_cache_reader.dart';
export 'src/workspace/workspace_loader.dart';
