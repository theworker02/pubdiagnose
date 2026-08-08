import 'package:pubdiagnose/src/cli/runner.dart';
import 'package:pubdiagnose/src/migration_knowledge/migration_catalog.dart';
import 'package:pubdiagnose/src/migration_knowledge/migration_rule.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('migration knowledge', () {
    test('explain matches version-scoped rules with provenance', () {
      final catalog = MigrationCatalog();
      final explained = catalog.explainPackage(
        package: 'http',
        from: '0.13.0',
        to: '1.0.0',
      );
      expect(explained.rules, isNotEmpty);
      expect(
        explained.rules.every(
          (r) => r.provenance == MigrationProvenance.pubdoctor,
        ),
        isTrue,
      );
    });

    test('provenance ledger records rule ids', () {
      final ledger = MigrationProvenanceLedger();
      ledger.record(
        ruleId: 'http-1-to-2-client',
        file: 'lib/main.dart',
        description: 'documented API note',
        provenance: MigrationProvenance.pubdoctor,
      );
      expect(ledger.edits.single['ruleId'], 'http-1-to-2-client');
    });

    test('migration explain cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'migration',
          'explain',
          'http',
          '0.13',
          '1.0',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"command": "migration"'));
      expect(out.toString(), contains('provenance'));
    });
  });
}
