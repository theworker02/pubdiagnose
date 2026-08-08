import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor doctor-report`
class DoctorReportCommand extends PubDoctorCommand {
  /// Creates the command.
  DoctorReportCommand() {
    argParser
      ..addFlag(
        'include-source',
        help: 'Include more path detail (still no file bodies).',
        negatable: false,
      )
      ..addFlag('json', help: 'Emit JSON (default).', negatable: false);
  }

  @override
  String get name => 'doctor-report';

  @override
  String get description =>
      'Emit a sanitized environment/diagnostic report (no secrets by default).';

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
      final report = kernel.doctorReport(
        includeSource: argResults!['include-source'] == true,
      );
      console.writeJson({'command': 'doctor-report', ...report});
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
