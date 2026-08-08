import 'package:args/command_runner.dart';

import '../../analysis/package_explainer.dart';
import '../../diagnostics/diagnostic_catalog.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor explain <PD####|package>`
class ExplainCommand extends PubDoctorCommand {
  /// Creates the command.
  ExplainCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'explain';

  @override
  String get description =>
      'Explain a diagnostic code (e.g. PD1001) or a local package.';

  @override
  String get invocation => 'pubdoctor explain <PD####|package> [--json]';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Missing diagnostic code or package name.', usage);
    }
    final target = argResults!.rest.first;
    final codeInfo = DiagnosticCatalog.byCode(target);

    if (codeInfo != null) {
      if (console.json) {
        console.writeJson({'command': 'explain', ...codeInfo.toJson()});
        return ExitCodes.ok;
      }
      console.title('${codeInfo.code} — ${codeInfo.title}');
      console.line('Severity: ${codeInfo.severity.name}');
      console.line();
      console.line(codeInfo.meaning);
      console.line();
      console.line('Why:');
      console.line('  ${codeInfo.why}');
      console.line();
      console.line('Fixes:');
      for (final f in codeInfo.fixes) {
        console.line('  • $f');
      }
      console.line();
      console.muted('Related: ${codeInfo.relatedCommand}');
      return ExitCodes.ok;
    }

    final workspace = await loadWorkspace();
    final explanation = await PackageExplainer(
      workspace: workspace,
      repository: pd.doctor.repository,
    ).explain(target);

    if (console.json) {
      console.writeJson({'command': 'explain', ...explanation.toJson()});
      return explanation.present ? ExitCodes.ok : ExitCodes.diagnostics;
    }

    console.title('Package: ${explanation.package}');
    if (!explanation.present) {
      console.warning(explanation.notes.join('\n'));
      return ExitCodes.diagnostics;
    }
    if (explanation.version != null) {
      console.line('Version: ${explanation.version}');
    }
    if (explanation.dependencyKind != null) {
      console.muted('Kind: ${explanation.dependencyKind}');
    }
    if (explanation.declaredSection != null) {
      console.line(
        'Declared: ${explanation.declaredSection} '
        '${explanation.declaredConstraint ?? ''}',
      );
    }
    if (explanation.overrideSummary != null) {
      console.warning('Override: ${explanation.overrideSummary}');
    }
    if (explanation.shortestPath != null) {
      console.line('Path: ${explanation.shortestPath}');
    }
    if (explanation.introducedBy.isNotEmpty) {
      console.muted('Introduced by: ${explanation.introducedBy.join(', ')}');
    }
    if (explanation.latestStable != null) {
      console.line(
        'Latest stable: ${explanation.latestStable}'
        '${explanation.latest != null && explanation.latest != explanation.latestStable ? ' (latest ${explanation.latest})' : ''}',
      );
    }
    if (explanation.sdkConstraint != null) {
      console.muted('SDK constraint: ${explanation.sdkConstraint}');
    }
    if (explanation.isDiscontinued) {
      console.warning(
        explanation.replacedBy == null
            ? 'Discontinued on the package repository.'
            : 'Discontinued; replaced by ${explanation.replacedBy}.',
      );
    }
    for (final b in explanation.blockers) {
      console.muted('Blocker: $b');
    }
    for (final n in explanation.notes) {
      console.muted(n);
    }
    if (explanation.offline) {
      console.muted('Offline / metadata unavailable.');
    }
    return ExitCodes.ok;
  }
}
