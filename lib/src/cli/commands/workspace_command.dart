import '../../workspace/monorepo_analyzer.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor workspace`
class WorkspaceCommand extends PubDoctorCommand {
  /// Creates the command.
  WorkspaceCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'workspace';

  @override
  String get description =>
      'Analyze Dart/pub workspaces and monorepos for inconsistent versions, '
      'SDK constraints, overrides, and cycles.';

  @override
  Future<int> run() async {
    final report =
        await MonorepoAnalyzer().analyze(pd.projectPath(argResults!));

    if (console.json) {
      console.writeJson({'command': 'workspace', ...report.toJson()});
      return report.diagnostics.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title('Workspace analysis');
    console.muted(
      report.isWorkspace
          ? 'Detected pub workspace: field'
          : 'No workspace: field — discovered nearby packages',
    );
    console.line('Members (${report.members.length}):');
    for (final m in report.members) {
      console.line(
        '  • ${m.name} (${m.relativePath})'
        '${m.pubspec.environment.sdk != null ? ' sdk ${m.pubspec.environment.sdk}' : ''}',
      );
    }
    console.line();

    if (report.diagnostics.isEmpty) {
      console.success('No workspace inconsistencies detected.');
      return ExitCodes.ok;
    }
    for (final d in report.diagnostics) {
      console.diagnostic(d);
    }
    return ExitCodes.diagnostics;
  }
}
