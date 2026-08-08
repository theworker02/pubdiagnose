import 'package:args/command_runner.dart';

import '../../impact/impact_report.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor impact …`
class ImpactCommand extends PubDoctorCommand {
  /// Creates the command.
  ImpactCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'impact';

  @override
  String get description => 'Simulate change impact for upgrades or removals.';

  @override
  String get invocation =>
      'pubdoctor impact <package> <version> | remove <package> | upgrade';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException(
        'Expected: <package> <version> | remove <package> | upgrade',
        usage,
      );
    }

    late final ChangeSimulation simulation;
    final head = rest.first.toLowerCase();
    if (head == 'upgrade') {
      simulation =
          const ChangeSimulation(kind: ChangeSimulationKind.upgradeAll);
    } else if (head == 'remove') {
      if (rest.length < 2) {
        throw UsageException('Expected package after remove.', usage);
      }
      simulation = ChangeSimulation(
        kind: ChangeSimulationKind.removePackage,
        package: rest[1],
      );
    } else {
      if (rest.length < 2) {
        throw UsageException(
          'Expected version after package name (or use remove/upgrade).',
          usage,
        );
      }
      simulation = ChangeSimulation(
        kind: ChangeSimulationKind.upgradePackage,
        package: rest[0],
        version: rest[1],
      );
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final result = await kernel.impact(simulation);
      if (result is OperationFailure<ImpactReport>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final report = result.valueOrNull!;
      if (console.json) {
        console.writeJson({'command': 'impact', ...report.toJson()});
      } else {
        _render(console, report);
      }
      return report.diagnostics.isNotEmpty && !report.safeToApply
          ? ExitCodes.diagnostics
          : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }

  void _render(ConsoleWriter console, ImpactReport report) {
    console.title('CHANGE IMPACT');
    console.line('Proposed: ${report.simulation.kind.name}'
        '${report.simulation.package != null ? ' ${report.simulation.package}' : ''}'
        '${report.simulation.version != null ? ' → ${report.simulation.version}' : ''}');
    if (report.summary != null) console.line(report.summary!);
    console.line('Safe to apply (local evidence): ${report.safeToApply}');
    console.line('Affected packages: ${report.affectedPackages.length}');
    console.line();
    for (final p in report.affectedPackages.take(20)) {
      console.line('${p.name}${p.isDirect ? ' (direct)' : ''}');
      console.muted('  ${p.reason}');
    }
    for (final d in report.diagnostics) {
      console.diagnostic(d);
    }
  }
}
