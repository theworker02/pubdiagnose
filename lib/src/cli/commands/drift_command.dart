import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/health.dart';
import '../../risk/risk_report.dart';
import '../../workspace/workspace_loader.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor drift`
class DriftCommand extends PubDoctorCommand {
  /// Creates the command.
  DriftCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addOption(
        'baseline',
        help: 'Snapshot id to compare against (default: latest).',
      );
  }

  @override
  String get name => 'drift';

  @override
  String get description =>
      'Compare current dependency state to a stored snapshot.';

  @override
  Future<int> run() async {
    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final loaded = await kernel.loadWorkspace();
      if (loaded is OperationFailure<PubWorkspace>) {
        console.error(loaded.message);
        return ExitCodes.invalid;
      }
      final ws = loaded.valueOrNull!;
      final store = kernel.snapshotStore();

      RiskReport? risk;
      final riskResult = await kernel.risk(offline: true);
      if (riskResult is! OperationFailure<RiskReport>) {
        risk = riskResult.valueOrNull;
      }
      final check = await kernel.check(offline: true);
      final diagnostics = check is! OperationFailure<HealthReport>
          ? check.valueOrNull?.diagnostics
          : null;

      final diff = store.drift(
        ws,
        baselineId: argResults!['baseline'] as String?,
        risk: risk,
        diagnostics: diagnostics,
      );
      if (diff == null) {
        console.error(
          'No snapshot baseline. Run: pubdoctor snapshot create',
        );
        return ExitCodes.invalid;
      }

      if (console.json) {
        console.writeJson({'command': 'drift', ...diff.toJson()});
      } else {
        console.title('DEPENDENCY DRIFT');
        console.line('Since ${diff.fromId}:');
        if (!diff.hasDrift) {
          console.success('No drift detected.');
        } else {
          for (final c in diff.changes.take(50)) {
            console.line(c);
          }
        }
      }
      return diff.hasDrift ? ExitCodes.diagnostics : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
