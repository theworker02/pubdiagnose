import '../../environment_snapshot/environment_diff.dart';
import '../../environment_snapshot/environment_snapshot.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor reproduce check|export`
class ReproduceCommand extends PubDoctorCommand {
  /// Creates the command.
  ReproduceCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'reproduce';

  @override
  String get description =>
      'Check or export sanitized environment reproduction manifests.';

  @override
  String get invocation => 'pubdoctor reproduce <check|export>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty || (rest.first != 'check' && rest.first != 'export')) {
      console.error('Expected: reproduce check | reproduce export');
      return ExitCodes.invalid;
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final snapResult = await kernel.environmentSnapshot();
      if (snapResult is OperationFailure<EnvironmentSnapshot>) {
        console.error(snapResult.message);
        return ExitCodes.invalid;
      }
      final snap = snapResult.valueOrNull!;

      if (rest.first == 'export') {
        final manifest = ReproduceReport.exportManifest(snap);
        if (console.json) {
          console.writeJson({
            'command': 'reproduce',
            'action': 'export',
            'manifest': manifest,
          });
        } else {
          console.title('REPRODUCTION MANIFEST');
          for (final e in manifest.entries) {
            console.line('${e.key}: ${e.value}');
          }
        }
        return ExitCodes.ok;
      }

      final report = ReproduceReport.check(snap);
      if (console.json) {
        console.writeJson({
          'command': 'reproduce',
          'action': 'check',
          ...report.toJson(),
        });
      } else {
        console.title('REPRODUCE CHECK');
        if (report.ok) {
          console
              .success('Environment looks reproducible for local resolution.');
        } else {
          for (final f in report.findings) {
            console.warning(f);
          }
        }
      }
      return report.ok ? ExitCodes.ok : ExitCodes.diagnostics;
    } finally {
      await kernel.close();
    }
  }
}
