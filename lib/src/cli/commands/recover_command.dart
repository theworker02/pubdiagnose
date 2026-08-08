import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor recover`
class RecoverCommand extends PubDoctorCommand {
  /// Creates the command.
  RecoverCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'recover';

  @override
  String get description =>
      'Recover from interrupted mutations, partial writes, and cache corruption.';

  @override
  Future<int> run() async {
    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(repository: pd.doctor.repository),
    );
    try {
      final result = await kernel.recover();
      return result.when(
        ok: (data) {
          if (console.json) {
            console.writeJson({'command': 'recover', ...data});
          } else {
            console.title('PubDoctor recover');
            final actions = data['actions'];
            if (actions is List && actions.isEmpty) {
              console.success('Nothing to recover.');
            } else if (actions is List) {
              for (final a in actions) {
                console.line('• $a');
              }
              console.success('Recovery complete.');
            }
          }
          return ExitCodes.ok;
        },
        fail: (f) {
          console.error(f.message);
          return ExitCodes.invalid;
        },
      );
    } finally {
      await kernel.close();
    }
  }
}
