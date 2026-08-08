import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor inspect`
class InspectCommand extends PubDoctorCommand {
  /// Creates the command.
  InspectCommand() {
    argParser.addFlag(
      'json',
      help: 'Emit JSON (always on for inspect).',
      negatable: false,
    );
  }

  @override
  String get name => 'inspect';

  @override
  String get description =>
      'Machine-readable workspace/capability inspection for IDEs and CI.';

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
      final payload = await kernel.inspect();
      console.writeJson({'command': 'inspect', ...payload});
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
