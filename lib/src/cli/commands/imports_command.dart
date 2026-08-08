import '../../diagnostics/import_analyzer.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor imports`
class ImportsCommand extends PubDoctorCommand {
  /// Creates the command.
  ImportsCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'imports';

  @override
  String get description =>
      'Detect direct imports of packages not declared in pubspec '
      '(PD1301).';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final analyzer = ImportAnalyzer(workspace);
    final findings = analyzer.analyze();
    final diagnostics = analyzer.toDiagnostics(findings);

    if (console.json) {
      console.writeJson({
        'command': 'imports',
        'findings': [for (final f in findings) f.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      });
      return findings.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title('Direct imports vs pubspec declarations');
    console.line();
    if (findings.isEmpty) {
      console.success('No undeclared direct imports detected.');
      return ExitCodes.ok;
    }

    for (final d in diagnostics) {
      console.diagnostic(d);
    }
    return ExitCodes.diagnostics;
  }
}
