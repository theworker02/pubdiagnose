import 'dart:convert';

import 'package:args/command_runner.dart';

import '../../features/feature_registry.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/diagnostics.dart';
import '../../verification/verification_controller.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor audit repair|internal`
class AuditCommand extends PubDoctorCommand {
  /// Creates the command.
  AuditCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'audit';

  @override
  String get description =>
      'Audit repair history or internal architecture consistency.';

  @override
  String get invocation => 'pubdoctor audit <repair|internal> [--json]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Expected repair or internal.', usage);
    }
    final action = rest.first.toLowerCase();

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      switch (action) {
        case 'repair':
          final path = kernel.execution.platform.paths.join(
            kernel.execution.workspacePath,
            '.dart_tool',
            'pubdoctor',
            'repair',
            'history.jsonl',
          );
          final raw = kernel.execution.platform.fs.readText(path);
          final entries = <Map<String, Object?>>[];
          if (raw != null) {
            for (final line in raw.split('\n')) {
              if (line.trim().isEmpty) continue;
              try {
                entries.add(Map<String, Object?>.from(jsonDecode(line) as Map));
              } on Object {
                continue;
              }
            }
          }
          if (console.json) {
            console.writeJson({
              'command': 'audit',
              'action': 'repair',
              'entries': entries,
            });
          } else {
            console.title('REPAIR HISTORY');
            if (entries.isEmpty) {
              console.line('No repair transactions recorded.');
            } else {
              for (final e in entries.take(20)) {
                console.line(
                  'Transaction ${e['transaction']}  outcome=${e['outcome']}',
                );
                console.muted('  ${e['ops'] ?? e['filesChanged']}');
              }
            }
          }
          return ExitCodes.ok;

        case 'internal':
          final features = FeatureRegistry.builtins().ids;
          final commands = pd.commands.keys.toList()..sort();
          final codes = _diagnosticCodes();
          final report = InternalAudit.run(
            featureIds: features,
            commandNames: commands,
            diagnosticCodes: codes,
          );
          if (console.json) {
            console.writeJson({
              'command': 'audit',
              'action': 'internal',
              ...report,
            });
          } else {
            console.title('INTERNAL AUDIT');
            console.line('Features: ${report['featureCount']}');
            console.line('Commands: ${report['commandCount']}');
            console.line('Diagnostic codes: ${report['diagnosticCount']}');
            final missing = report['missingExpected'] as List? ?? const [];
            if (missing.isEmpty) {
              console.success('No orphan gaps vs expected command set.');
            } else {
              console.warning('Missing expected: ${missing.join(', ')}');
            }
          }
          return report['ok'] == true ? ExitCodes.ok : ExitCodes.diagnostics;

        default:
          throw UsageException('Expected repair or internal.', usage);
      }
    } finally {
      await kernel.close();
    }
  }

  List<String> _diagnosticCodes() {
    return [
      DiagnosticCodes.dependencyConflict,
      DiagnosticCodes.riskDiscontinued,
      DiagnosticCodes.policyViolation,
      DiagnosticCodes.impactWarning,
      DiagnosticCodes.snapshotDrift,
    ];
  }
}
