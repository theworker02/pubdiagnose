import 'package:args/command_runner.dart';

import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../sandbox/project_sandbox.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor upgrade simulate|heal`
class UpgradeCommand extends PubDoctorCommand {
  /// Creates the command.
  UpgradeCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addOption('package', help: 'Package name for simulate/heal.')
      ..addOption('version', help: 'Target version.')
      ..addFlag(
        'pub-get',
        help: 'Run dart pub get inside the sandbox (optional).',
        negatable: false,
      );
  }

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Simulate upgrades in a sandbox or report upgrade heal status.';

  @override
  String get invocation =>
      'pubdoctor upgrade <simulate|heal> [--package] [--version]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Expected simulate or heal.', usage);
    }
    final action = rest.first.toLowerCase();
    final package =
        argResults!['package'] as String? ?? (rest.length > 1 ? rest[1] : null);
    final version =
        argResults!['version'] as String? ?? (rest.length > 2 ? rest[2] : null);

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(repository: pd.doctor.repository),
    );
    try {
      switch (action) {
        case 'simulate':
          if (package == null || version == null) {
            throw UsageException(
              'simulate requires --package and --version',
              usage,
            );
          }
          final result = await SandboxExecutor.simulateUpgrade(
            workspacePath: kernel.execution.workspacePath,
            package: package,
            version: version,
            runPubGet: argResults!['pub-get'] == true,
          );
          if (console.json) {
            console.writeJson({
              'command': 'upgrade',
              'action': 'simulate',
              ...result.toJson(),
            });
          } else {
            console.title('UPGRADE SIMULATE');
            console.line(result.message ?? '');
            for (final n in result.notes) {
              console.muted(n);
            }
          }
          return result.ok ? ExitCodes.ok : ExitCodes.diagnostics;

        case 'heal':
          if (package == null || version == null) {
            throw UsageException(
              'heal requires --package and --version',
              usage,
            );
          }
          // Report-only heal loop summary using sandbox + source checker.
          final sim = await SandboxExecutor.simulateUpgrade(
            workspacePath: kernel.execution.workspacePath,
            package: package,
            version: version,
            runPubGet: false,
          );
          final payload = {
            'target': '$package → $version',
            'status': 'PARTIALLY_REPAIRABLE',
            'initialAnalyzerErrors': sim.analyzerErrors ?? 0,
            'automaticRepairs': 0,
            'remaining': sim.analyzerErrors ?? 0,
            'notes': [
              'Behavioral migrations are never auto-guessed.',
              ...sim.notes,
            ],
          };
          if (console.json) {
            console.writeJson({
              'command': 'upgrade',
              'action': 'heal',
              ...payload,
            });
          } else {
            console.title('UPGRADE HEAL');
            console.line('Target: $package → $version');
            console.line('Status: PARTIALLY REPAIRABLE');
            console.muted(
              'Use repair --safe for deterministic dependency fixes; '
              'behavioral API migrations require manual review.',
            );
          }
          return ExitCodes.ok;

        default:
          throw UsageException('Expected simulate or heal.', usage);
      }
    } finally {
      await kernel.close();
    }
  }
}
