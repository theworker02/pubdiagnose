import 'package:args/command_runner.dart';

import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../policy/policy_result.dart';
import '../../policy/policy_rule.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor policy check|list|explain`
class PolicyCommand extends PubDoctorCommand {
  /// Creates the command.
  PolicyCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'policy';

  @override
  String get description =>
      'Workspace governance policy check / list / explain.';

  @override
  String get invocation =>
      'pubdoctor policy <check|list|explain> [rule-id] [--json]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final action = rest.isEmpty ? 'check' : rest.first.toLowerCase();

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final rules = kernel.execution.config.policies;

      switch (action) {
        case 'list':
          if (console.json) {
            console.writeJson({
              'command': 'policy',
              'action': 'list',
              'rules': [for (final r in rules) r.toJson()],
            });
          } else {
            console.title('POLICY RULES');
            if (rules.isEmpty) {
              console.line('No policies configured in pubdoctor.yaml.');
              console.muted(
                'Add a policies: block to enable governance checks.',
              );
            } else {
              for (final r in rules) {
                console.line(
                  '${r.id} (${r.kind.name}) '
                  '${r.enabled ? 'enabled' : 'disabled'}',
                );
                if (r.description != null) {
                  console.muted('  ${r.description}');
                }
              }
            }
          }
          return ExitCodes.ok;

        case 'explain':
          if (rest.length < 2) {
            throw UsageException('Expected rule id after explain.', usage);
          }
          final id = rest[1];
          PolicyRule? match;
          for (final r in rules) {
            if (r.id == id || r.kind.name == id) {
              match = r;
              break;
            }
          }
          if (match == null) {
            console.error('Unknown policy rule "$id".');
            return ExitCodes.invalid;
          }
          if (console.json) {
            console.writeJson({
              'command': 'policy',
              'action': 'explain',
              ...match.toJson(),
            });
          } else {
            console.title('POLICY RULE ${match.id}');
            console.line('Kind: ${match.kind.name}');
            console.line('Enabled: ${match.enabled}');
            if (match.description != null) console.line(match.description!);
            if (match.params.isNotEmpty) {
              console.line('Params: ${match.params}');
            }
          }
          return ExitCodes.ok;

        case 'check':
          final result = await kernel.policyCheck();
          if (result is OperationFailure<PolicyResult>) {
            console.error(result.message);
            return ExitCodes.invalid;
          }
          final report = result.valueOrNull!;
          if (console.json) {
            console.writeJson({'command': 'policy', ...report.toJson()});
          } else {
            _render(console, report);
          }
          return report.hasViolations ? ExitCodes.diagnostics : ExitCodes.ok;

        default:
          throw UsageException('Expected check, list, or explain.', usage);
      }
    } finally {
      await kernel.close();
    }
  }

  void _render(ConsoleWriter console, PolicyResult report) {
    console.title('POLICY CHECK');
    console.line('Rules evaluated: ${report.rulesEvaluated}');
    if (report.sourcePath != null) {
      console.muted('Source: ${report.sourcePath}');
    }
    if (report.findings.isEmpty) {
      console.success('No policy violations.');
      return;
    }
    for (final f in report.findings) {
      console.diagnostic(f.toDiagnostic());
    }
  }
}
