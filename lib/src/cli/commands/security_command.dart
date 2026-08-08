import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/diagnostics.dart';
import '../../security/supply_chain_analyzer.dart';
import '../../workspace/workspace_loader.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor security` / `pubdoctor security lockfile`
class SecurityCommand extends PubDoctorCommand {
  /// Creates the command.
  SecurityCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'security';

  @override
  String get description => 'Supply-chain and lockfile integrity analysis.';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
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
      final analyzer = SupplyChainAnalyzer(
        workspace: loaded.valueOrNull!,
        policy: kernel.execution.config.security,
      );

      final diagnostics = rest.isNotEmpty && rest.first == 'lockfile'
          ? analyzer.lockfileIntegrity()
          : analyzer.analyze();
      final applied = kernel.execution.config.apply(diagnostics);
      final trust = analyzer.trustTable();

      if (console.json) {
        console.writeJson({
          'command': 'security',
          'action': rest.isNotEmpty ? rest.first : 'analyze',
          'policy': kernel.execution.config.security.toJson(),
          'trust': [for (final t in trust) t.toJson()],
          'diagnostics': [for (final d in applied) d.toJson()],
        });
      } else {
        console.title(
          rest.isNotEmpty && rest.first == 'lockfile'
              ? 'SECURITY LOCKFILE'
              : 'SECURITY',
        );
        if (applied.isEmpty) {
          console.success('No security findings.');
        } else {
          for (final d in applied) {
            console.diagnostic(d);
          }
        }
      }
      final failed = applied.any(
        (d) => d.severity.index >= DiagnosticSeverity.warning.index,
      );
      return failed ? ExitCodes.diagnostics : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
