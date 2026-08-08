import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor migration explain <pkg> <from> <to>`
class MigrationCommand extends PubDoctorCommand {
  /// Creates the command.
  MigrationCommand() {
    argParser.addFlag('json', help: 'Emit JSON.', negatable: false);
  }

  @override
  String get name => 'migration';

  @override
  String get description =>
      'Explain semantic package/SDK migrations from the knowledge catalog.';

  @override
  String get invocation => 'pubdoctor migration explain <pkg> <from> <to>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length < 4 || rest.first != 'explain') {
      console.error('Expected: migration explain <pkg> <from> <to>');
      return ExitCodes.invalid;
    }
    final package = rest[1];
    final from = rest[2];
    final to = rest[3];

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final explained = kernel.migrationCatalog().explainPackage(
            package: package,
            from: from,
            to: to,
          );
      if (console.json) {
        console.writeJson({
          'command': 'migration',
          'action': 'explain',
          ...explained.toJson(),
        });
      } else {
        console.title('MIGRATION EXPLAIN: $package $from → $to');
        if (explained.rules.isEmpty) {
          console.line('No version-scoped rules matched.');
        }
        for (final rule in explained.rules) {
          console.line(
              'Rule ${rule.id} (${rule.provenance.name}, risk ${rule.risk})');
          for (final c in rule.apiChanges) {
            console.line('  ${c.fromSymbol} → ${c.toSymbol}');
            if (c.notes != null) console.muted('    ${c.notes}');
            console.muted(
              '    automated: ${c.automated}  kind: ${c.kind}',
            );
          }
          for (final u in rule.unsupportedBehavioral) {
            console.warning('  Unsupported behavioral: $u');
          }
          for (final v in rule.verification) {
            console.muted('  verify: $v');
          }
        }
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
