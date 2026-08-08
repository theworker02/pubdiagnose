import 'package:args/command_runner.dart';

import '../../config/baseline.dart';
import '../../diagnostics/health_analyzer.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor baseline create|inspect|update|clean`
class BaselineCommand extends PubDoctorCommand {
  /// Creates the command.
  BaselineCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'baseline';

  @override
  String get description =>
      'Manage .pubdoctor_baseline.json for CI new-violation detection.';

  @override
  String get invocation =>
      'pubdoctor baseline <create|inspect|update|clean> [--json]';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException(
        'Expected create, inspect, update, or clean.',
        usage,
      );
    }
    final action = argResults!.rest.first.toLowerCase();
    final project = pd.projectPath(argResults!);
    final store = BaselineStore(project);

    switch (action) {
      case 'inspect':
        final info = store.inspect();
        if (console.json) {
          console.writeJson({'command': 'baseline', 'action': action, ...info});
        } else {
          console.title('Baseline');
          console.line('path: ${info['path']}');
          console.line('exists: ${info['exists']}');
          console.line('entries: ${info['entryCount']}');
        }
        return ExitCodes.ok;
      case 'clean':
        final deleted = store.clean();
        if (console.json) {
          console.writeJson({
            'command': 'baseline',
            'action': action,
            'deleted': deleted,
          });
        } else {
          console.success(deleted ? 'Baseline deleted.' : 'No baseline file.');
        }
        return ExitCodes.ok;
      case 'create':
      case 'update':
        final workspace = await loadWorkspace();
        final report = HealthAnalyzer(workspace: workspace).analyze();
        final baseline = action == 'create'
            ? store.create(
                report.diagnostics,
                project: workspace.pubspec.name,
              )
            : store.update(
                report.diagnostics,
                project: workspace.pubspec.name,
              );
        if (console.json) {
          console.writeJson({
            'command': 'baseline',
            'action': action,
            ...baseline.toJson(),
          });
        } else {
          console.success(
            '${action == 'create' ? 'Created' : 'Updated'} baseline with '
            '${baseline.entries.length} entr${baseline.entries.length == 1 ? 'y' : 'ies'}.',
          );
        }
        return ExitCodes.ok;
      default:
        throw UsageException(
          'Unknown baseline action "$action".',
          usage,
        );
    }
  }
}
