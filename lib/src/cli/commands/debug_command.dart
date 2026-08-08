import 'package:args/command_runner.dart';

import '../../constraints/constraint_analyzer.dart';
import '../../diagnostics/import_analyzer.dart';
import '../../diagnostics/unused_analyzer.dart';
import '../../incremental/incremental_engine.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor debug profile`
class DebugCommand extends PubDoctorCommand {
  /// Creates the command.
  DebugCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'debug';

  @override
  String get description =>
      'Profiling and incremental invalidation diagnostics (experimental).';

  @override
  String get invocation => 'pubdoctor debug profile [--json]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final action = rest.isEmpty ? 'profile' : rest.first.toLowerCase();
    if (action != 'profile') {
      throw UsageException('Expected: debug profile', usage);
    }

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final inc = await kernel.incremental();
      if (inc is OperationFailure<IncrementalEngine>) {
        console.error(inc.message);
        return ExitCodes.invalid;
      }
      final engine = inc.valueOrNull!;
      final loaded = await kernel.loadWorkspace();
      final ws = loaded.valueOrNull!;

      final profile = await engine.profile(
        runStep: (name) async {
          switch (name) {
            case 'load':
              return;
            case 'constraints':
              ConstraintAnalyzer(ws).analyze(includeNarrow: false);
            case 'graph':
              ws.graph.transitiveDependencies().length;
            case 'imports':
              try {
                ImportAnalyzer(ws).analyze();
              } on Object {
                // ignore
              }
            case 'unused':
              try {
                UnusedAnalyzer(ws).analyze();
              } on Object {
                // ignore
              }
          }
        },
      );

      if (console.json) {
        console
            .writeJson({'command': 'debug', 'action': 'profile', ...profile});
      } else {
        console.title('DEBUG PROFILE');
        console.line('Total: ${profile['totalMs']} ms');
        final timings = profile['timings'] as List<dynamic>? ?? const [];
        for (final t in timings) {
          if (t is Map) {
            console.line('${t['name']}: ${t['ms']} ms');
          }
        }
        final plan = profile['plan'] as Map<String, Object?>? ?? {};
        console.line();
        console.line('Invalidated: ${plan['invalidatedAnalyzers']}');
        console.line('Changed parts: ${plan['changedParts']}');
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
