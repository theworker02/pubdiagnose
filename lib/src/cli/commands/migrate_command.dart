import 'package:args/command_runner.dart';

import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../migrations/migration_plan.dart';
import '../../migrations/migration_planner.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor migrate …`
class MigrateCommand extends PubDoctorCommand {
  /// Creates the command.
  MigrateCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'save',
        help: 'Persist the plan under .dart_tool/pubdoctor/migrations/.',
        negatable: false,
      );
  }

  @override
  String get name => 'migrate';

  @override
  String get description =>
      'Plan ordered SDK / package migrations without mutating the project.';

  @override
  String get invocation =>
      'pubdoctor migrate <dart|flutter|package|status|resume> [args] [--save]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException(
        'Expected: dart <ver> | flutter <ver> | package <name> <ver> | '
        'status | resume',
        usage,
      );
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(repository: pd.doctor.repository),
    );
    try {
      final plannerResult = await kernel.migrationPlanner();
      if (plannerResult is OperationFailure<MigrationPlanner>) {
        console.error(plannerResult.message);
        return ExitCodes.invalid;
      }
      final planner = plannerResult.valueOrNull!;
      final action = rest.first.toLowerCase();
      final save = argResults!['save'] == true;

      switch (action) {
        case 'status':
          final status = planner.status();
          if (console.json) {
            console.writeJson(
                {'command': 'migrate', 'action': 'status', ...status});
          } else {
            console.title('MIGRATION STATUS');
            if (status['active'] != true) {
              console.line('No active migration.');
            } else {
              final plan = planner.active();
              if (plan != null) _renderPlan(console, plan);
            }
          }
          return ExitCodes.ok;

        case 'resume':
          final plan = planner.resume();
          if (console.json) {
            console.writeJson({
              'command': 'migrate',
              'action': 'resume',
              ...plan.toJson(),
            });
          } else {
            console.title('MIGRATION RESUMED');
            _renderPlan(console, plan);
          }
          return ExitCodes.ok;

        case 'dart':
        case 'flutter':
          if (rest.length < 2) {
            throw UsageException('Expected version after $action.', usage);
          }
          final plan = action == 'dart'
              ? await planner.planDartSdk(rest[1])
              : await planner.planFlutterSdk(rest[1]);
          if (save) planner.save(plan);
          return _emit(plan, save);

        case 'package':
          if (rest.length < 3) {
            throw UsageException(
              'Expected: migrate package <name> <version>',
              usage,
            );
          }
          final plan = await planner.planPackage(rest[1], rest[2]);
          if (save) planner.save(plan);
          return _emit(plan, save);

        default:
          throw UsageException(
            'Unknown migrate action "$action".',
            usage,
          );
      }
    } finally {
      await kernel.close();
    }
  }

  int _emit(MigrationPlan plan, bool saved) {
    if (console.json) {
      console.writeJson({
        'command': 'migrate',
        'saved': saved,
        ...plan.toJson(),
      });
    } else {
      console.title(
        '${plan.targetKind.name.toUpperCase()} MIGRATION PLAN'
        '${saved ? ' (saved)' : ''}',
      );
      _renderPlan(console, plan);
      if (!saved) {
        console.muted('Tip: re-run with --save to persist under '
            '.dart_tool/pubdoctor/migrations/');
      }
    }
    return ExitCodes.ok;
  }

  void _renderPlan(ConsoleWriter console, MigrationPlan plan) {
    console.line('Id: ${plan.id}');
    console.line('Target: ${plan.target}'
        '${plan.package != null ? ' (${plan.package})' : ''}');
    console.line('Overall risk: ${plan.overallRisk.name}');
    console.line('Steps: ${plan.steps.length}');
    console.line();
    var i = 0;
    for (final step in plan.steps) {
      i++;
      console.line('Step $i [${step.status.name}] ${step.title}');
      console.muted('  ${step.description}');
      if (step.fromVersion != null || step.toVersion != null) {
        console.muted(
          '  ${step.fromVersion ?? '?'} → ${step.toVersion ?? '?'}',
        );
      }
      console.muted('  risk: ${step.risk.level.name}');
      for (final e in step.evidence.take(3)) {
        console.muted('  • $e');
      }
      console.line();
    }
  }
}
