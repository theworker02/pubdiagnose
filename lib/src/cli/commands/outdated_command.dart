import '../../recommendations/recommendation_engine.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor outdated`
class OutdatedCommand extends PubDoctorCommand {
  /// Creates the command.
  OutdatedCommand() {
    argParser
      ..addFlag(
        'json',
        help: 'Emit JSON.',
        negatable: false,
      )
      ..addFlag(
        'direct',
        help: 'Only analyze direct dependencies.',
        negatable: false,
      );
  }

  @override
  String get name => 'outdated';

  @override
  String get description =>
      'Show outdated packages and explain what blocks upgrades.';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final outdated = await pd.doctor.outdated(
      workspace,
      directOnly: argResults!['direct'] == true,
    );
    final recommendations =
        RecommendationEngine(workspace).fromOutdated(outdated);

    if (console.json) {
      console.writeJson({
        'command': 'outdated',
        'packages': [for (final o in outdated) o.toJson()],
        'recommendations': [for (final r in recommendations) r.toJson()],
      });
      return outdated.isEmpty ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    if (outdated.isEmpty) {
      console.success(
          'No outdated hosted packages detected (or metadata unavailable).');
      return ExitCodes.ok;
    }

    console.title('Outdated packages');
    console.muted(
      'Explanations use the dependency graph + package metadata. '
      'This is not a drop-in replacement for `dart pub outdated`.',
    );
    console.line();

    for (final o in outdated) {
      console.line('${o.package}: ${o.current}');
      if (o.latestCompatible != null) {
        console.muted('  latest compatible: ${o.latestCompatible}');
      }
      if (o.latestStable != null) {
        console.muted('  latest stable:     ${o.latestStable}');
      }
      if (o.explanation != null) {
        console.line('  ${o.explanation}');
      }
      for (final b in o.blockers.take(3)) {
        console.muted('  blocked by ${b.blockedBy}: ${b.constraint}');
        if (b.path != null) console.muted('    path: ${b.path}');
      }
      console.line();
    }

    if (recommendations.isNotEmpty && console.verbose) {
      console.title('Recommendations');
      for (final r in recommendations.take(10)) {
        console.line('[${r.confidence.name}] ${r.package}: ${r.explanation}');
      }
    }

    return ExitCodes.diagnostics;
  }
}
