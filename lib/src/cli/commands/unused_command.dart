import '../../diagnostics/unused_analyzer.dart';
import '../../models/health.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor unused`
class UnusedCommand extends PubDoctorCommand {
  /// Creates the command.
  UnusedCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'unused';

  @override
  String get description =>
      'Find declared dependencies with no direct package: imports.';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final analyzer = UnusedAnalyzer(workspace);
    final findings = analyzer.analyze();
    final actionable =
        findings.where((f) => f.confidence != UnusedConfidence.low).toList();
    final diagnostics = analyzer.toDiagnostics(findings);

    if (console.json) {
      console.writeJson({
        'command': 'unused',
        'findings': [for (final f in findings) f.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      });
      return actionable.any((f) => f.confidence == UnusedConfidence.high)
          ? ExitCodes.diagnostics
          : ExitCodes.ok;
    }

    console.title('Possibly unused dependencies');
    console.muted(
      'Low-confidence items are omitted from diagnostics. Tooling packages '
      'are medium confidence even without imports.',
    );
    console.line();

    if (findings.isEmpty) {
      console.success('No unused dependency candidates.');
      return ExitCodes.ok;
    }

    for (final f in findings) {
      console.line('${f.package} (${f.section}) — ${f.confidence.name}');
      for (final r in f.reasons) {
        console.muted('  • $r');
      }
      console.line();
    }

    return actionable.any((f) => f.confidence == UnusedConfidence.high)
        ? ExitCodes.diagnostics
        : ExitCodes.ok;
  }
}
