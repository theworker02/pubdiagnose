import 'dart:convert';

import '../../config/baseline.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/diagnostics.dart';
import '../../models/health.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor check` — routes through [PubDoctorKernel].
class CheckCommand extends PubDoctorCommand {
  /// Creates the command.
  CheckCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'jsonl',
        help: 'Stream diagnostics as JSON Lines (one object per line).',
        negatable: false,
      )
      ..addFlag(
        'ci',
        help: 'CI mode: non-interactive, config-aware, deterministic exits.',
        negatable: false,
      )
      ..addOption(
        'fail-on',
        help: 'Fail when diagnostics at or above this severity exist.',
        allowed: ['info', 'warning', 'error', 'critical'],
      )
      ..addFlag(
        'baseline',
        help: 'Only fail on diagnostics not in .pubdoctor_baseline.json.',
        negatable: false,
      )
      ..addFlag(
        'offline',
        help: 'Skip pub.dev outdated enrichment.',
        negatable: false,
      )
      ..addOption(
        'workers',
        help: 'Local distributed worker count for independent analysis slices.',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Unified local dependency health report (conflicts, overrides, imports, '
      'unused, outdated).';

  @override
  Future<int> run() async {
    final project = pd.projectPath(argResults!);
    final offline = argResults!['offline'] == true;
    final ci = argResults!['ci'] == true;
    final jsonl = argResults!['jsonl'] == true;
    final workersRaw = argResults!['workers'] as String?;
    final workers = workersRaw == null ? null : int.tryParse(workersRaw);
    final minimal = pd.globalResults['minimal'] == true;

    final kernel = await PubDoctorKernel.create(
      workspacePath: project,
      options: PubDoctorOptions(
        offline: offline,
        repository: pd.doctor.repository,
        minimal: minimal,
        workers: workers,
      ),
    );

    try {
      final result = await kernel.check(offline: offline, workers: workers);
      if (result is OperationFailure<HealthReport>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final report = result.valueOrNull!;
      var diagnostics = report.diagnostics;

      final useBaseline = argResults!['baseline'] == true;
      if (useBaseline) {
        diagnostics = BaselineStore(project).load().newViolations(diagnostics);
      }

      final failOn = _failOn(kernel);
      final shouldFail =
          diagnostics.any((d) => d.severity.index >= failOn.index);

      if (jsonl) {
        const encoder = JsonEncoder();
        for (final d in diagnostics) {
          console.out.writeln(
            encoder.convert({'type': 'diagnostic', ...d.toJson()}),
          );
        }
        console.out.writeln(
          encoder.convert({
            'type': 'summary',
            'command': 'check',
            'status': report.status.name,
            'failed': shouldFail,
            'count': diagnostics.length,
          }),
        );
        return shouldFail ? ExitCodes.diagnostics : ExitCodes.ok;
      }

      if (console.json) {
        console.writeJson({
          'command': 'check',
          'schemaVersion': 1,
          'ci': ci,
          'status': report.status.name,
          'summary': report.summary,
          'failOn': failOn.name,
          'failed': shouldFail,
          'baselineFiltered': useBaseline,
          'counts': report.toJson()['counts'],
          'hasLockfile': report.hasLockfile,
          'diagnostics': [for (final d in diagnostics) d.toJson()],
          if (console.verbose)
            'outdated': [for (final o in report.outdated) o.toJson()],
        });
        return shouldFail ? ExitCodes.diagnostics : ExitCodes.ok;
      }

      console.title('PubDiagnose / Diagnose your Dart dependencies.');
      console.line();
      console.title('check: ${report.projectName}');
      switch (report.status) {
        case HealthStatus.healthy:
          console.success('HEALTHY');
        case HealthStatus.attentionRequired:
          console.warning('ATTENTION REQUIRED');
        case HealthStatus.unhealthy:
          console.error('UNHEALTHY');
      }
      if (report.summary != null) console.line(report.summary!);
      console.line();
      console.line(
        'Dependencies: ${report.directDependencyCount} direct, '
        '${report.devDependencyCount} dev, '
        '${report.transitiveDependencyCount} transitive',
      );
      console.line(
        'Overrides: ${report.overrideCount}  '
        'Conflicts: ${report.conflictCount}  '
        'Outdated: ${report.outdatedCount}  '
        'Constrained upgrades: ${report.constrainedUpgradeCount}',
      );
      console.line();

      if (diagnostics.isEmpty) {
        console.success(
          useBaseline
              ? 'No new diagnostics beyond baseline.'
              : 'No diagnostics.',
        );
      } else {
        for (final d in diagnostics) {
          console.diagnostic(d);
        }
      }

      if (ci) console.muted('CI mode · fail-on ${failOn.name}');
      return shouldFail ? ExitCodes.diagnostics : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }

  DiagnosticSeverity _failOn(PubDoctorKernel kernel) {
    final raw = argResults!['fail-on'] as String?;
    if (raw == null) return kernel.execution.config.failOn;
    return switch (raw) {
      'info' => DiagnosticSeverity.info,
      'warning' => DiagnosticSeverity.warning,
      'critical' => DiagnosticSeverity.critical,
      _ => DiagnosticSeverity.error,
    };
  }
}
