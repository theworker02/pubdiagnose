import '../../constraints/constraint_analyzer.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor conflicts`
class ConflictsCommand extends PubDoctorCommand {
  /// Creates the command.
  ConflictsCommand() {
    argParser.addFlag(
      'json',
      help: 'Emit JSON.',
      negatable: false,
    );
  }

  @override
  String get name => 'conflicts';

  @override
  String get description =>
      'Detect conflicting or fragile version constraints.';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final analyzer = ConstraintAnalyzer(workspace);
    final conflicts = analyzer.analyze();
    final diagnostics = analyzer.toDiagnostics(conflicts);

    if (console.json) {
      console.writeJson({
        'command': 'conflicts',
        'conflictCount': conflicts.length,
        'conflicts': [for (final c in conflicts) c.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      });
      return conflicts.any((c) => c.intersection.isEmpty)
          ? ExitCodes.diagnostics
          : (conflicts.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics);
    }

    if (conflicts.isEmpty) {
      console.success('No constraint conflicts detected.');
      return ExitCodes.ok;
    }

    console.title('Constraint analysis');
    console.line();
    for (final d in diagnostics) {
      console.diagnostic(d);
    }

    final errors = conflicts.where((c) => c.intersection.isEmpty).length;
    console.muted(
      '$errors conflict(s), ${conflicts.length - errors} narrow intersection(s).',
    );
    return ExitCodes.diagnostics;
  }
}
