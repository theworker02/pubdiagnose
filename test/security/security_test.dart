import 'package:pubdiagnose/src/cli/runner.dart';
import 'package:pubdiagnose/src/security/package_integrity.dart';
import 'package:pubdiagnose/src/security/supply_chain_analyzer.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('security', () {
    test('security lockfile cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'security',
          'lockfile',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "security"'));
    });

    test('policy rejects git when disallowed', () {
      final policy = const SecurityPolicy(allowGitDependencies: false);
      expect(policy.allowGitDependencies, isFalse);
      expect(SourcePolicy.isDefaultHost('pub.dev'), isTrue);
      expect(SourcePolicy.isDefaultHost('https://evil.example'), isFalse);
    });

    test('checksum mismatch diagnostic', () {
      final d = ChecksumValidator().validate(
        package: 'foo',
        expected: 'abc',
        actual: 'xyz',
      );
      expect(d, isNotNull);
      expect(d!.code, SecurityCodes.checksumMismatch);
    });
  });
}
