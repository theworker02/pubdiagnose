import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/diagnostics.dart';
import '../../risk/risk_report.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor risk [package]`
class RiskCommand extends PubDoctorCommand {
  /// Creates the command.
  RiskCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'offline',
        help: 'Skip pub.dev metadata enrichment.',
        negatable: false,
      );
  }

  @override
  String get name => 'risk';

  @override
  String get description =>
      'Evidence-driven dependency risk intelligence (maintenance, '
      'compatibility, concentration).';

  @override
  String get invocation => 'pubdoctor risk [package] [--offline] [--json]';

  @override
  Future<int> run() async {
    final package = argResults!.rest.isEmpty ? null : argResults!.rest.first;
    final offline = argResults!['offline'] == true;

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: offline,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final result = await kernel.risk(package: package, offline: offline);
      if (result is OperationFailure<RiskReport>) {
        console.error(result.message);
        return ExitCodes.invalid;
      }
      final report = result.valueOrNull!;
      if (console.json) {
        console.writeJson({'command': 'risk', ...report.toJson()});
      } else {
        _render(console, report);
      }
      final fail = report.diagnostics.any(
        (d) =>
            d.severity == DiagnosticSeverity.error ||
            d.severity == DiagnosticSeverity.critical,
      );
      return fail ? ExitCodes.diagnostics : ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }

  void _render(ConsoleWriter console, RiskReport report) {
    console.title('PACKAGE RISK');
    console.line('Project: ${report.projectName}');
    console.line('Worst category: ${report.worstCategory.name}');
    if (report.focusPackage != null) {
      console.line('Focus: ${report.focusPackage}');
    }
    console.line();
    if (report.packages.isEmpty) {
      console.success('No risk signals detected.');
      return;
    }
    for (final pkg in report.packages) {
      console.line(
          '${pkg.package}${pkg.lockedVersion != null ? ' ${pkg.lockedVersion}' : ''}');
      console.line('  Risk level: ${pkg.worstCategory.name.toUpperCase()}');
      console.line('  Signals:');
      for (final s in pkg.signals) {
        console.line(
            '  [${s.category.name.toUpperCase()} ${s.confidence.name}] ${s.title}');
        console.muted('    ${s.message}');
        for (final e in s.evidence.take(4)) {
          console.muted('    • $e');
        }
        if (s.remediation != null) {
          console.line('    → ${s.remediation}');
        }
      }
      console.line();
    }
    if (report.concentration.isNotEmpty) {
      console.title('CONCENTRATION');
      for (final c in report.concentration.take(10)) {
        console.line(
          '${c.package}: ${c.pathCount} paths, ${c.parentCount} parents',
        );
      }
    }
  }
}
