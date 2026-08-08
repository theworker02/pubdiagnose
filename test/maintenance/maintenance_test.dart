import 'package:pubdiagnose/src/cli/runner.dart';
import 'package:pubdiagnose/src/maintenance/maintenance_controller.dart';
import 'package:pubdiagnose/src/maintenance/maintenance_plan.dart';
import 'package:pubdiagnose/src/models/diagnostics.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('maintenance', () {
    test('actions ordered by priority; limits stop runaway', () {
      final history = MaintenanceHistory(
        seed: [
          {
            'id': 'R-001942',
            'rollbackSafe': false,
            'introducedDiagnostics': ['PD1001'],
          },
        ],
      );
      final controller = MaintenanceController(history: history);
      final plan = controller.plan(
        security: [
          const Diagnostic(
            code: 'PDSEC01',
            title: 'git',
            message: 'git dep',
            severity: DiagnosticSeverity.error,
          ),
        ],
        source: [
          const Diagnostic(
            code: 'PDS101',
            title: 'import',
            message: 'Add missing direct dependency',
            severity: DiagnosticSeverity.warning,
          ),
        ],
        pubdoctorHealthy: false,
        sdkWarnings: ['Prepare Dart SDK migration recommendation'],
      );
      expect(
          plan.actions.first.priority, MaintenancePriority.internalCorruption);
      expect(
        plan.actions.map((a) => a.priority.index).toList(),
        orderedEquals(
          plan.actions.map((a) => a.priority.index).toList()..sort(),
        ),
      );

      final result = controller.run(
        policy: const MaintenancePolicy(
          mode: MaintenanceMode.safe,
          repairHistory: true,
          limits: MaintenanceLimits(maxActions: 1),
        ),
        plan: plan,
        currentDiagnosticCodes: {'PD1001'},
      );
      expect(result.applied.length, lessThanOrEqualTo(1));
      expect(result.compensating, isNotEmpty);
      expect(
        result.toJson()['autonomyContract'],
        contains('loop indefinitely'),
      );
    });

    test('maintain --audit cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'maintain',
          '--audit',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"command": "maintain"'));
      expect(out.toString(), contains('"mode": "audit"'));
    });

    test('ecosystem offline cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'ecosystem',
          '--offline',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"command": "ecosystem"'));
    });

    test('check --workers and --ci dogfood', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'check',
          '--ci',
          '--offline',
          '--workers',
          '2',
          '--json',
          '--project',
          '.',
        ],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "check"'));
    });
  });
}
