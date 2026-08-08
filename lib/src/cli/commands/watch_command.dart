import 'dart:async';

import '../../integrity/integrity_engine.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor watch`
class WatchCommand extends PubDoctorCommand {
  /// Creates the command.
  WatchCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON events.', negatable: false)
      ..addFlag(
        'heal-safe',
        help: 'Auto-heal PubDoctor-owned state only on changes.',
        negatable: false,
      )
      ..addFlag(
        'repair-safe',
        help: 'Suggest (and optionally apply) T1 safe repairs — opt-in.',
        negatable: false,
      )
      ..addOption(
        'duration',
        help: 'Milliseconds to watch before exit (tests / CI).',
      );
  }

  @override
  String get name => 'watch';

  @override
  String get description =>
      'Watch dependency/config files and reanalyze incrementally.';

  @override
  Future<int> run() async {
    final durationMs = int.tryParse(argResults!['duration'] as String? ?? '');
    final healSafe = argResults!['heal-safe'] == true;
    final repairSafe = argResults!['repair-safe'] == true;

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final result = await kernel.integrity();
      if (result is OperationFailure<IntegrityEngine>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final engine = result.valueOrNull!;
      engine.snapshot();

      if (!console.json) {
        console.title('WATCH');
        console.line('Watching pubspec / lock / pubdoctor config…');
        if (durationMs == null) {
          console.muted('Pass --duration <ms> to auto-stop (or Ctrl+C).');
        }
      }

      final sub = engine.watch().listen((event) async {
        if (console.json) {
          console.writeJson({'command': 'watch', 'event': event.toJson()});
        } else {
          console.line('[${event.kind}] ${event.path}');
          final plan = await kernel.incremental();
          plan.when(
            ok: (inc) {
              final p = inc.plan();
              console.muted(
                'Re-run: ${(p['invalidatedAnalyzers'] as List?)?.join(', ')}',
              );
            },
            fail: (_) {},
          );
        }
        if (healSafe) {
          final heal = await kernel.healingEngine().plan(safeOnly: true);
          if (heal.actions.isNotEmpty) {
            await kernel.healingEngine().apply(heal);
            if (!console.json) {
              console.muted('Applied safe internal heal.');
            }
          }
        }
        if (repairSafe) {
          final rep = await kernel.repairEngine();
          await rep.when(
            ok: (engine) async {
              final plan = await engine.plan(safeOnly: true);
              if (plan.candidates.isNotEmpty && !console.json) {
                console.line(
                  'Safe repair available: pubdoctor repair --safe --apply',
                );
                for (final c in plan.candidates.take(3)) {
                  console.muted('  ${c.description}');
                }
              }
            },
            fail: (_) async {},
          );
        }
      });

      if (durationMs != null) {
        await Future<void>.delayed(Duration(milliseconds: durationMs));
        await sub.cancel();
      } else {
        // Block until cancelled — in practice tests use --duration.
        await Completer<void>().future;
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
