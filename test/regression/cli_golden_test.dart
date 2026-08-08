import 'package:pubdiagnose/pubdiagnose.dart';
import 'package:pubdiagnose/src/cli/console.dart';
import 'package:pubdiagnose/src/cli/runner.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final doctor = PubDoctor(
    loader: WorkspaceLoader(enrichFromCache: false),
  );

  test('doctor-report emits sanitized JSON', () async {
    final out = StringBuffer();
    final code = await runPubDoctor(
      [
        '--project',
        fixturePath('basic_app'),
        'doctor-report',
      ],
      doctor: doctor,
      out: out,
      err: StringBuffer(),
    );
    expect(code, ExitCodes.ok);
    expect(out.toString(), contains('"command": "doctor-report"'));
    expect(out.toString(), contains('"version"'));
    expect(out.toString().toLowerCase(), isNot(contains('password')));
  });

  test('cache status works', () async {
    final out = StringBuffer();
    final code = await runPubDoctor(
      [
        '--project',
        fixturePath('basic_app'),
        'cache',
        'status',
        '--json',
      ],
      doctor: doctor,
      out: out,
      err: StringBuffer(),
    );
    expect(code, ExitCodes.ok);
    expect(out.toString(), contains('"action": "status"'));
  });

  test('check --jsonl streams summary', () async {
    final out = StringBuffer();
    final code = await runPubDoctor(
      [
        '--project',
        fixturePath('basic_app'),
        'check',
        '--offline',
        '--jsonl',
      ],
      doctor: doctor,
      out: out,
      err: StringBuffer(),
    );
    expect(code, anyOf(ExitCodes.ok, ExitCodes.diagnostics));
    expect(out.toString(), contains('"type":"summary"'));
  });
}
