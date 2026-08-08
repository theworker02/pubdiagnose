import '../../remediation/fix_applier.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor fix`
class FixCommand extends PubDoctorCommand {
  /// Creates the command.
  FixCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'apply',
        help: 'Apply the plan to pubspec.yaml (otherwise propose only).',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Validate mutations without writing.',
        negatable: false,
      )
      ..addFlag(
        'safe',
        help: 'Only include non-breaking changes.',
        negatable: false,
      );
  }

  @override
  String get name => 'fix';

  @override
  String get description =>
      'Propose (default) or apply safe pubspec remediations. Never silent.';

  @override
  String get invocation =>
      'pubdoctor fix [PD####|package] [--apply|--dry-run] [--safe] [--json]';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final rest = argResults!.rest;
    String? code;
    String? package;
    if (rest.isNotEmpty) {
      final token = rest.first;
      if (RegExp(r'^PD\d+', caseSensitive: false).hasMatch(token) ||
          token.toLowerCase() == 'analyzer' ||
          token.toLowerCase() == 'overrides' ||
          token.toLowerCase() == 'unused' ||
          token.toLowerCase() == 'imports') {
        code = token.toLowerCase() == 'analyzer' ? 'PD1101' : token;
      } else {
        package = token;
      }
    }

    final applier = FixApplier(workspace);
    final plan = applier.propose(
      code: code,
      package: package,
      safeOnly: argResults!['safe'] == true,
    );

    final apply = argResults!['apply'] == true;
    final dryRun = argResults!['dry-run'] == true;

    if (console.json) {
      if (apply || dryRun) {
        final result = await applier.apply(plan, dryRun: dryRun || !apply);
        console.writeJson({
          'command': 'fix',
          ...result.toJson(),
        });
        return result.applied || dryRun
            ? ExitCodes.ok
            : (plan.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics);
      }
      console.writeJson({'command': 'fix', 'plan': plan.toJson()});
      return plan.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title('PubDoctor fix plan');
    console.muted('Default mode proposes only — pass --apply to write.');
    console.line('Risk: ${plan.risk.name}');
    console.line();

    if (plan.isEmpty) {
      console.success('No automatic fixes available for the current filters.');
      return ExitCodes.ok;
    }

    for (final c in plan.changes) {
      console.line('WHAT: ${c.what}');
      console.line('WHY:  ${c.why}');
      for (final e in c.evidence.take(4)) {
        console.muted('  evidence: $e');
      }
      console.line('EXPECTED RESULT: ${c.expectedResult}');
      console.line('RISK: ${c.risk.name}');
      console.line();
    }

    console.muted(
      'Would resolve ${plan.resolvedDiagnostics.length} diagnostic(s); '
      '${plan.remainingDiagnostics.length} remaining.',
    );

    if (!apply && !dryRun) {
      console.line();
      console.line('Re-run with --apply to write, or --dry-run to validate.');
      return ExitCodes.diagnostics;
    }

    final result = await applier.apply(plan, dryRun: dryRun || !apply);
    if (result.rolledBack) {
      console.error(result.message ?? 'Rolled back.');
      return ExitCodes.invalid;
    }
    if (dryRun) {
      console.success(result.message ?? 'Dry run OK.');
      return ExitCodes.ok;
    }
    if (result.applied) {
      console.success(result.message ?? 'Applied.');
      return ExitCodes.ok;
    }
    console.warning(result.message ?? 'Not applied.');
    return ExitCodes.diagnostics;
  }
}
