import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor health`
class HealthCommand extends PubDoctorCommand {
  /// Creates the command.
  HealthCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'health';

  @override
  String get description =>
      'Internal PubDoctor subsystem health (cache, schemas, journals).';

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
      final report = await kernel.healingEngine().healthReport();
      if (console.json) {
        console.writeJson({'command': 'health', ...report});
      } else {
        console.title('PUBDOCTOR HEALTH');
        final subs = report['subsystems'] as Map<String, Object?>? ?? {};
        for (final e in subs.entries) {
          console.line('${e.key.padRight(22)} ${e.value}');
        }
        final count = report['issueCount'] as int? ?? 0;
        console.line();
        console.line('$count recoverable issue(s) detected.');
        final issues = report['issues'] as List<dynamic>? ?? const [];
        for (final i in issues) {
          if (i is Map) {
            console.line('${i['code']} ${i['title']}');
            console.muted('  ${i['message']}');
          }
        }
        if (count > 0) {
          console.line();
          console.muted('Run: pubdoctor heal');
        }
      }
      final count = report['issueCount'] as int? ?? 0;
      return count > 0 ? ExitCodes.diagnostics : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}

/// `pubdoctor heal`
class HealCommand extends PubDoctorCommand {
  /// Creates the command.
  HealCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'apply',
        help: 'Apply the healing plan (default is plan-only).',
        negatable: false,
      )
      ..addFlag(
        'safe',
        help: 'Only low-risk internal PubDoctor state repairs.',
        negatable: false,
      );
  }

  @override
  String get name => 'heal';

  @override
  String get description =>
      'Plan or apply internal PubDoctor self-healing (T0).';

  @override
  Future<int> run() async {
    final apply = argResults!['apply'] == true;
    final safe = argResults!['safe'] == true;

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final engine = kernel.healingEngine();
      final plan = await engine.plan(safeOnly: safe);
      if (!apply) {
        if (console.json) {
          console.writeJson(
              {'command': 'heal', 'action': 'plan', ...plan.toJson()});
        } else {
          console.title('HEALING PLAN');
          if (plan.actions.isEmpty) {
            console.success('No healing actions required.');
          } else {
            var i = 0;
            for (final a in plan.actions) {
              i++;
              console.line('$i. ${a.description}');
              console.muted(
                  '   Risk: ${a.risk.name}  Confidence: ${a.confidence.name}');
            }
            console.line();
            console.line('No project source files will be modified.');
            console.muted('Run: pubdoctor heal --apply');
          }
        }
        return ExitCodes.ok;
      }

      final result = await engine.apply(plan);
      if (console.json) {
        console.writeJson(
            {'command': 'heal', 'action': 'apply', ...result.toJson()});
      } else {
        console.title('HEALING RESULT');
        console.line(result.message ?? (result.success ? 'ok' : 'failed'));
        for (final a in result.actions) {
          console.line('• $a');
        }
        if (result.rolledBack) {
          console
              .warning('Changes were rolled back after verification failure.');
        }
      }
      return result.success ? ExitCodes.ok : ExitCodes.diagnostics;
    } finally {
      await kernel.close();
    }
  }
}
