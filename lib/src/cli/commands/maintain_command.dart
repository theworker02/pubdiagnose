import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../maintenance/maintenance_controller.dart';
import '../../maintenance/maintenance_plan.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor maintain`
class MaintainCommand extends PubDoctorCommand {
  /// Creates the command.
  MaintainCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag('audit', help: 'Audit only — no mutations.', negatable: false)
      ..addFlag(
        'safe',
        help: 'Apply only deterministic low-risk actions.',
        negatable: false,
      )
      ..addFlag('apply',
          help: 'Apply approved plan under safeguards.', negatable: false)
      ..addFlag('ci',
          help: 'Machine-oriented non-interactive mode.', negatable: false)
      ..addFlag(
        'repair-history',
        help: 'Scan prior PubDoctor transactions for regressions.',
        negatable: false,
      );
  }

  @override
  String get name => 'maintain';

  @override
  String get description =>
      'Bounded autonomous maintenance controller (audit / safe / apply / ci).';

  @override
  Future<int> run() async {
    final audit = argResults!['audit'] == true;
    final safe = argResults!['safe'] == true;
    final apply = argResults!['apply'] == true;
    final ci = argResults!['ci'] == true;
    final repairHistory = argResults!['repair-history'] == true;

    final mode = apply
        ? MaintenanceMode.apply
        : safe
            ? MaintenanceMode.safe
            : ci
                ? MaintenanceMode.ci
                : MaintenanceMode.audit;

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
        minimal: pd.globalResults['minimal'] == true,
      ),
    );
    try {
      final result = await kernel.maintain(
        policy: MaintenancePolicy(
          mode: mode,
          repairHistory: repairHistory || audit,
        ),
      );
      if (result is OperationFailure<MaintenanceResult>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final value = result.valueOrNull!;
      if (console.json || ci) {
        console.writeJson({
          'command': 'maintain',
          'ci': ci,
          ...value.toJson(),
        });
      } else {
        console.title('MAINTENANCE PLAN');
        for (final e in value.plan.summary.entries) {
          console.line('${e.key.padRight(22)} ${e.value}');
        }
        console.line();
        console.line('Proposed actions:');
        var i = 0;
        for (final a in value.plan.actions) {
          i++;
          console.line('$i. ${a.description}');
        }
        if (value.plan.actions.isEmpty) {
          console.success('No actions proposed.');
        }
        console.line();
        console.muted(value.stoppedReason);
        if (value.compensating.isNotEmpty) {
          console.warning('Compensating transactions available:');
          for (final c in value.compensating) {
            console.line('  prior ${c['priorTransaction']}: ${c['reason']}');
          }
        }
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
