import 'package:args/command_runner.dart';

import '../console.dart';
import '../runner.dart';

/// `pubdoctor sdk dart|flutter <version>`
class SdkCommand extends PubDoctorCommand {
  /// Creates the command.
  SdkCommand() {
    argParser.addFlag(
      'json',
      help: 'Emit JSON.',
      negatable: false,
    );
  }

  @override
  String get name => 'sdk';

  @override
  String get description =>
      'Explain which dependencies block a target Dart or Flutter SDK version.';

  @override
  String get invocation => 'pubdoctor sdk <dart|flutter> <version> [--json]';

  @override
  Future<int> run() async {
    if (argResults!.rest.length < 2) {
      throw UsageException(
        'Expected `pubdoctor sdk dart|flutter <version>`.',
        usage,
      );
    }
    final kind = argResults!.rest[0].toLowerCase();
    final version = argResults!.rest[1];
    if (kind != 'dart' && kind != 'flutter') {
      throw UsageException('First argument must be dart or flutter.', usage);
    }

    final workspace = await loadWorkspace();
    final report = kind == 'dart'
        ? await pd.doctor.sdkDart(workspace, version)
        : await pd.doctor.sdkFlutter(workspace, version);

    if (console.json) {
      console.writeJson({
        'command': 'sdk',
        ...report.toJson(),
      });
      return report.blockers.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title('SDK upgrade: ${report.kind} ${report.target}');
    console.line(report.explanation);
    console.line();

    if (report.blockers.isEmpty) {
      console.success('No package SDK blockers found for this target.');
    } else {
      for (final b in report.blockers) {
        console.line('• ${b.package} @ ${b.version}');
        console.muted('  requires ${report.kind} ${b.constraint}');
        if (b.path != null) console.muted('  path: ${b.path}');
      }
    }

    if (report.recommendations.isNotEmpty) {
      console.line();
      console.line('Recommendations:');
      for (final r in report.recommendations.take(12)) {
        console.line('[${r.confidence.name}] ${r.package}: ${r.explanation}');
        for (final c in r.changes) {
          console.muted('  ${c.description} (${c.risk.name})');
        }
      }
    }

    if (kind == 'flutter') {
      console.line();
      console.muted('Does not require Flutter to be installed locally.');
    }

    return report.blockers.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
  }
}
