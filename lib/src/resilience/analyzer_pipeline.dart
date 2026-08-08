import '../kernel/capability_registry.dart';
import '../kernel/execution_context.dart';
import '../models/diagnostics.dart';
import '../workspace/workspace_loader.dart';

/// Severity behavior when a module fails.
enum ModuleFailureSeverity {
  /// Ignore the failure.
  ignore,

  /// Record as info diagnostic.
  info,

  /// Record as warning.
  warning,

  /// Record as error but continue pipeline.
  error,

  /// Abort the entire pipeline.
  abort,
}

/// Contract for a fault-isolated analyzer module.
abstract class AnalyzerModule {
  /// Stable module id.
  String get id;

  /// Module ids that should run first.
  List<String> get dependsOn => const [];

  /// Capabilities that must be present.
  List<PubDoctorCapability> get requiredCapabilities => const [];

  /// Capabilities used when available.
  List<PubDoctorCapability> get optionalCapabilities => const [];

  /// Timeout for this module.
  Duration get timeout => const Duration(seconds: 60);

  /// Behavior when the module throws / times out.
  ModuleFailureSeverity get onFailure => ModuleFailureSeverity.warning;

  /// Run the module; return diagnostics (may be empty).
  Future<List<Diagnostic>> run(
    ExecutionContext context,
    PubWorkspace workspace,
  );
}

/// Result of running the analyzer pipeline.
class PipelineResult {
  /// Creates a result.
  const PipelineResult({
    required this.diagnostics,
    required this.moduleStatuses,
    this.abortedBy,
  });

  /// Aggregated diagnostics.
  final List<Diagnostic> diagnostics;

  /// Per-module status maps.
  final List<Map<String, Object?>> moduleStatuses;

  /// Module that aborted the pipeline, if any.
  final String? abortedBy;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'diagnostics': [for (final d in diagnostics) d.toJson()],
        'modules': moduleStatuses,
        if (abortedBy != null) 'abortedBy': abortedBy,
      };
}

/// Fault-isolated analyzer pipeline.
class AnalyzerPipeline {
  /// Creates a pipeline.
  AnalyzerPipeline(this.modules);

  /// Modules in registration order (deps resolved).
  final List<AnalyzerModule> modules;

  /// Run all modules against [workspace].
  Future<PipelineResult> run(
    ExecutionContext context,
    PubWorkspace workspace,
  ) async {
    final diagnostics = <Diagnostic>[];
    final statuses = <Map<String, Object?>>[];
    final completed = <String>{};
    String? abortedBy;

    final pending = [...modules];
    while (pending.isNotEmpty) {
      context.checkpoint();
      final ready =
          pending.where((m) => m.dependsOn.every(completed.contains)).toList();
      if (ready.isEmpty) {
        // Break dependency cycles by running next anyway.
        ready.add(pending.first);
      }

      for (final module in ready) {
        pending.remove(module);
        if (!_capsSatisfied(context, module)) {
          statuses.add({
            'id': module.id,
            'status': 'skipped',
            'reason': 'missing_capabilities',
          });
          completed.add(module.id);
          continue;
        }

        final sw = Stopwatch()..start();
        try {
          final result =
              await module.run(context, workspace).timeout(module.timeout);
          diagnostics.addAll(result);
          statuses.add({
            'id': module.id,
            'status': 'ok',
            'diagnostics': result.length,
            'ms': sw.elapsedMilliseconds,
          });
        } on Object catch (e) {
          final sev = module.onFailure;
          statuses.add({
            'id': module.id,
            'status': 'failed',
            'error': e.toString(),
            'ms': sw.elapsedMilliseconds,
          });
          if (sev == ModuleFailureSeverity.abort) {
            abortedBy = module.id;
            diagnostics.add(
              Diagnostic(
                code: 'PD0008',
                title: 'Analyzer module aborted',
                message: 'Module ${module.id} failed: $e',
                severity: DiagnosticSeverity.error,
                remediation:
                    'Re-run with --verbose or pubdoctor doctor-report.',
              ),
            );
            return PipelineResult(
              diagnostics: diagnostics,
              moduleStatuses: statuses,
              abortedBy: abortedBy,
            );
          }
          if (sev != ModuleFailureSeverity.ignore) {
            diagnostics.add(
              Diagnostic(
                code: 'PD0009',
                title: 'Analyzer module failed',
                message:
                    'Module ${module.id} failed but analysis continued: $e',
                severity: switch (sev) {
                  ModuleFailureSeverity.info => DiagnosticSeverity.info,
                  ModuleFailureSeverity.error => DiagnosticSeverity.error,
                  _ => DiagnosticSeverity.warning,
                },
              ),
            );
          }
        }
        completed.add(module.id);
      }
    }

    return PipelineResult(
      diagnostics: diagnostics,
      moduleStatuses: statuses,
      abortedBy: abortedBy,
    );
  }

  bool _capsSatisfied(ExecutionContext context, AnalyzerModule module) {
    for (final c in module.requiredCapabilities) {
      if (!context.capabilities.has(c)) return false;
    }
    return true;
  }
}
