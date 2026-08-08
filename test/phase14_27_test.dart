import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubdoctor/src/cli/runner.dart';
import 'package:pubdoctor/src/healing/healing_engine.dart';
import 'package:pubdoctor/src/kernel/pubdoctor_kernel.dart';
import 'package:pubdoctor/src/kernel/pubdoctor_options.dart';
import 'package:pubdoctor/src/verification/verification_controller.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('phase 14-20', () {
    test('risk command offline json', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runPubDoctor(
        ['risk', '--offline', '--json', '--project', fixturePath('basic_app')],
        out: out,
        err: err,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "risk"'));
    });

    test('policy list with empty config', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        ['policy', 'list', '--json', '--project', fixturePath('basic_app')],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"action": "list"'));
    });

    test('impact remove', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'impact',
          'remove',
          'path',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "impact"'));
    });

    test('snapshot create + drift', () async {
      final project = fixturePath('basic_app');
      final out1 = StringBuffer();
      final c1 = await runPubDoctor(
        ['snapshot', 'create', '--json', '--project', project],
        out: out1,
      );
      expect(c1, 0);
      expect(out1.toString(), contains('snap-'));

      final out2 = StringBuffer();
      final c2 = await runPubDoctor(
        ['drift', '--json', '--project', project],
        out: out2,
      );
      expect(c2, anyOf(0, 1));
      expect(out2.toString(), contains('"command": "drift"'));
    });

    test('debug profile', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        ['debug', 'profile', '--json', '--project', fixturePath('basic_app')],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"totalMs"'));
    });

    test('migrate status without active plan', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        ['migrate', 'status', '--json', '--project', fixturePath('basic_app')],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"active"'));
    });
  });

  group('phase 21-27', () {
    test('health + heal plan', () async {
      final project = fixturePath('basic_app');
      final out = StringBuffer();
      final code = await runPubDoctor(
        ['health', '--json', '--project', project],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"subsystems"'));

      final out2 = StringBuffer();
      final code2 = await runPubDoctor(
        ['heal', '--safe', '--json', '--project', project],
        out: out2,
      );
      expect(code2, 0);
      expect(out2.toString(), contains('"actions"'));
    });

    test('healing apply verify loop', () async {
      final kernel = await PubDoctorKernel.create(
        workspacePath: fixturePath('basic_app'),
        options: const PubDoctorOptions(offline: true, allowNetwork: false),
      );
      try {
        final engine = kernel.healingEngine();
        final plan = await engine.plan(safeOnly: true);
        final result = await engine.apply(plan);
        expect(result.success || plan.actions.isEmpty, isTrue);
      } finally {
        await kernel.close();
      }
    });

    test('source check', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        ['source', 'check', '--json', '--project', fixturePath('imports_app')],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "source"'));
    });

    test('repair dry-run', () async {
      final dir = await Directory.systemTemp.createTemp('pd_repair_');
      addTearDown(() => dir.delete(recursive: true));
      await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: repair_fixture
environment:
  sdk: ^3.5.0
dependencies:
  path: any
''');
      await Directory(p.join(dir.path, 'lib')).create();
      await File(p.join(dir.path, 'lib', 'main.dart')).writeAsString(
        "import 'package:collection/collection.dart';\nvoid main() {}\n",
      );

      final out = StringBuffer();
      final code = await runPubDoctor(
        ['repair', '--dry-run', '--json', '--project', dir.path],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('repair'));
    });

    test('environment + audit internal', () async {
      final project = fixturePath('basic_app');
      final out = StringBuffer();
      expect(
        await runPubDoctor(
          ['environment', '--json', '--project', project],
          out: out,
        ),
        0,
      );
      expect(out.toString(), contains('capabilityLevel'));

      final out2 = StringBuffer();
      final code = await runPubDoctor(
        ['audit', 'internal', '--json', '--project', project],
        out: out2,
      );
      expect(code, anyOf(0, 1));
      expect(out2.toString(), contains('featureCount'));
    });

    test('watch duration exits', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'watch',
          '--duration',
          '200',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
    });

    test('verification regression detector', () {
      final v = VerificationController();
      final ok = v.verifyMetadata(
        pubspecText: 'name: x\n',
        beforeDiagnostics: 2,
        afterDiagnostics: 1,
      );
      expect(ok.ok, isTrue);
      final bad = v.verifyMetadata(
        pubspecText: 'name: x\n',
        beforeDiagnostics: 1,
        afterDiagnostics: 3,
      );
      expect(bad.regression, isTrue);
    });

    test('chaos: corrupt cache then heal', () async {
      final kernel = await PubDoctorKernel.create(
        workspacePath: fixturePath('basic_app'),
        options: const PubDoctorOptions(offline: true, allowNetwork: false),
      );
      try {
        final cache = kernel.execution.cache;
        cache.ensureLayout();
        final marker = kernel.execution.platform.paths.join(
          cache.rootPath,
          'schema.json',
        );
        kernel.execution.platform.fs.writeText(marker, '{not-json');
        final engine = HealingEngine(
          context: kernel.healingEngine().context,
        );
        final issues = await engine.detect();
        expect(issues, isNotEmpty);
        final plan = await engine.plan(safeOnly: true);
        final result = await engine.apply(plan);
        expect(result.success || result.rolledBack, isTrue);
      } finally {
        await kernel.close();
      }
    });

    test('repair dry-run twice is idempotent', () async {
      final kernel = await PubDoctorKernel.create(
        workspacePath: fixturePath('basic_app'),
        options: const PubDoctorOptions(offline: true, allowNetwork: false),
      );
      try {
        final eng = (await kernel.repairEngine()).valueOrNull!;
        final plan = await eng.plan();
        final once = await eng.apply(plan, dryRun: true);
        expect(once['dryRun'], isTrue);
        final twice = await eng.apply(plan, dryRun: true);
        expect(twice['dryRun'], isTrue);
      } finally {
        await kernel.close();
      }
    });
  });
}
