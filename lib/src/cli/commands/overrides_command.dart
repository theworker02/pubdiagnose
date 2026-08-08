import '../../diagnostics/override_analyzer.dart';
import '../../models/recommendations.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor overrides`
class OverridesCommand extends PubDoctorCommand {
  /// Creates the command.
  OverridesCommand() {
    argParser
      ..addFlag(
        'json',
        help: 'Emit JSON.',
        negatable: false,
      )
      ..addOption(
        'test',
        help:
            'Print guidance for testing removal of a specific override (does not edit files).',
      );
  }

  @override
  String get name => 'overrides';

  @override
  String get description =>
      'Classify dependency_overrides as necessary, possibly unnecessary, unsafe, or unknown.';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final analyzer = OverrideAnalyzer(workspace);
    final analyses = analyzer.analyze();
    final diagnostics = analyzer.toDiagnostics(analyses);
    final testPackage = argResults!['test'] as String?;

    if (console.json) {
      console.writeJson({
        'command': 'overrides',
        'overrides': [for (final a in analyses) a.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
        if (testPackage != null) 'testGuidance': _testGuidance(testPackage),
      });
      return _exitCode(analyses);
    }

    if (analyses.isEmpty) {
      console.success('No dependency_overrides declared.');
      return ExitCodes.ok;
    }

    console.title('dependency_overrides analysis');
    console.muted('pubdoctor never edits pubspec.yaml automatically.');
    console.line();

    for (final a in analyses) {
      console.line('${a.package}: ${a.classification.name}');
      console.line('  ${a.explanation}');
      if (a.declaredConstraint != null) {
        console.muted('  override: ${a.declaredConstraint}');
      }
      if (a.resolvedVersion != null) {
        console.muted('  resolved: ${a.resolvedVersion}');
      }
      console.line();
    }

    for (final d in diagnostics) {
      if (console.verbose) console.diagnostic(d);
    }

    if (testPackage != null) {
      console.title('Test removal guidance: $testPackage');
      console.line(_testGuidance(testPackage));
    }

    return _exitCode(analyses);
  }

  int _exitCode(List<OverrideAnalysis> analyses) {
    final interesting = analyses.any(
      (a) =>
          a.classification == OverrideClassification.possiblyUnnecessary ||
          a.classification == OverrideClassification.unsafe ||
          a.classification == OverrideClassification.necessary,
    );
    // Necessary overrides are informational; treat unsafe/unnecessary as diagnostics.
    final issues = analyses.any(
      (a) =>
          a.classification == OverrideClassification.possiblyUnnecessary ||
          a.classification == OverrideClassification.unsafe,
    );
    return issues
        ? ExitCodes.diagnostics
        : (interesting ? ExitCodes.ok : ExitCodes.ok);
  }

  String _testGuidance(String package) =>
      'To test whether the override for "$package" is still needed:\n'
      '  1. Copy pubspec.yaml / pubspec.lock\n'
      '  2. Remove the dependency_overrides entry for $package\n'
      '  3. Run `dart pub get`\n'
      '  4. If resolution fails, restore the override and inspect '
      '`pubdoctor conflicts` / `pubdoctor why $package`\n'
      'pubdoctor will not perform these edits for you.';
}
