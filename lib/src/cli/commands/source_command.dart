import 'package:args/command_runner.dart';

import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../source/source_file.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor source check`
class SourceCommand extends PubDoctorCommand {
  /// Creates the command.
  SourceCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'source';

  @override
  String get description =>
      'Dart source project-level diagnostics (imports, parts).';

  @override
  String get invocation => 'pubdoctor source check [--json]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final action = rest.isEmpty ? 'check' : rest.first.toLowerCase();
    if (action != 'check') {
      throw UsageException('Expected: source check', usage);
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final result = await kernel.sourceCheck();
      if (result is OperationFailure<List<SourceDiagnostic>>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final diags = result.valueOrNull!;
      if (console.json) {
        console.writeJson({
          'command': 'source',
          'action': 'check',
          'diagnostics': [for (final d in diags) d.toJson()],
        });
      } else {
        console.title('SOURCE CHECK');
        if (diags.isEmpty) {
          console.success('No source-level project issues detected.');
        } else {
          for (final d in diags) {
            console.line('[${d.code}] ${d.message}');
            console.muted('  ${d.location.path}');
            if (d.repairHint != null) console.line('  → ${d.repairHint}');
          }
        }
      }
      return diags.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    } finally {
      await kernel.close();
    }
  }
}
