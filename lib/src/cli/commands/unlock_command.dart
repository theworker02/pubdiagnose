import 'package:args/command_runner.dart';

import '../console.dart';
import '../runner.dart';

/// `pubdoctor unlock <package> [version]`
class UnlockCommand extends PubDoctorCommand {
  /// Creates the command.
  UnlockCommand() {
    argParser.addFlag(
      'json',
      help: 'Emit JSON.',
      negatable: false,
    );
  }

  @override
  String get name => 'unlock';

  @override
  String get description =>
      'Explain what blocks upgrading a package to a target (or latest) version.';

  @override
  String get invocation => 'pubdoctor unlock <package> [version] [--json]';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Missing package name.', usage);
    }
    final package = argResults!.rest.first;
    final version = argResults!.rest.length > 1 ? argResults!.rest[1] : null;

    final workspace = await loadWorkspace();
    final report = await pd.doctor.unlock(
      workspace,
      package,
      version: version,
    );

    if (console.json) {
      console.writeJson({
        'command': 'unlock',
        ...report.toJson(),
      });
      return report.blockers.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title(
      'Unlock ${report.package} → ${report.desired}'
      '${report.current != null ? ' (from ${report.current})' : ''}',
    );
    console.line();

    if (report.blockers.isEmpty) {
      console.success(
        'No known graph constraints block ${report.package} ${report.desired}.',
      );
    } else {
      console.warning('${report.blockers.length} blocker(s):');
      for (final b in report.blockers) {
        console.line('  • ${b.blockedBy}: ${b.constraint}');
        console.muted('    ${b.explanation}');
        if (b.path != null) console.muted('    path: ${b.path}');
      }
    }

    if (report.recommendations.isNotEmpty) {
      console.line();
      console.title('Recommendations');
      for (final r in report.recommendations.take(8)) {
        console.line('[${r.confidence.name}] ${r.explanation}');
        for (final c in r.changes) {
          console.muted(
            '  change: ${c.description}'
            '${c.from != null ? ' (${c.from} → ${c.to})' : ''}'
            ' [${c.risk.name}]',
          );
        }
      }
    }

    console.line();
    console.muted(
      'Guidance only — pubdoctor does not rewrite pubspec.yaml unless you '
      'run `pubdoctor fix --apply`.',
    );

    return report.blockers.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
  }
}
