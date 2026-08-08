import 'package:args/command_runner.dart';

import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor cache status|clean|repair`
class CacheCommand extends PubDoctorCommand {
  /// Creates the command.
  CacheCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'cache';

  @override
  String get description =>
      'Inspect, clean, or repair `.dart_tool/pubdoctor` cache/state.';

  @override
  String get invocation => 'pubdoctor cache <status|clean|repair> [--json]';

  @override
  Future<int> run() async {
    final action = argResults!.rest.isEmpty
        ? 'status'
        : argResults!.rest.first.toLowerCase();
    if (!const {'status', 'clean', 'repair'}.contains(action)) {
      throw UsageException(
        'Expected status, clean, or repair.',
        usage,
      );
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(repository: pd.doctor.repository),
    );
    try {
      final result = kernel.cacheCommand(action);
      return result.when(
        ok: (data) {
          if (console.json) {
            console.writeJson({'command': 'cache', 'action': action, ...data});
          } else {
            console.title('PubDoctor cache $action');
            for (final e in data.entries) {
              console.line('${e.key}: ${e.value}');
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
