import 'dart:convert';

import 'package:pubdiagnose/pubdiagnose.dart';
import 'package:pubdiagnose/src/cli/console.dart';
import 'package:pubdiagnose/src/cli/runner.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final doctor = PubDoctor(
    loader: WorkspaceLoader(enrichFromCache: false),
  );

  test('why --json returns stable schema', () async {
    final out = StringBuffer();
    final code = await runPubDoctor(
      [
        '--project',
        fixturePath('basic_app'),
        'why',
        'matcher',
        '--json',
      ],
      doctor: doctor,
      out: out,
      err: StringBuffer(),
    );
    expect(code, ExitCodes.ok);
    final json = jsonDecode(out.toString()) as Map<String, dynamic>;
    expect(json['command'], 'why');
    expect(json['package'], 'matcher');
    expect(json['shortestPath'], isNotNull);
  });

  test('conflicts exits 1 when conflicts exist', () async {
    final code = await runPubDoctor(
      [
        '--no-color',
        '--project',
        fixturePath('conflict_app'),
        'conflicts',
        '--json',
      ],
      doctor: doctor,
      out: StringBuffer(),
      err: StringBuffer(),
    );
    expect(code, ExitCodes.diagnostics);
  });

  test('graph --json encodes tree', () async {
    final buffer = StringBuffer();
    final runner = PubDoctorCommandRunner(
      doctor: doctor,
      out: buffer,
      err: StringBuffer(),
    );
    final code = await runner.run([
      '--project',
      fixturePath('basic_app'),
      'graph',
      '--json',
    ]);
    expect(code, ExitCodes.ok);
    final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'graph');
    expect(json['root'], 'basic_app');
  });

  test('invalid project exits 2', () async {
    final err = StringBuffer();
    final code = await runPubDoctor(
      [
        '--project',
        fixturePath('nope'),
        'why',
        'x',
      ],
      doctor: doctor,
      out: StringBuffer(),
      err: err,
    );
    expect(code, ExitCodes.invalid);
    expect(err.toString(), contains('PD0004'));
  });
}
