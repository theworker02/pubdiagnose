import 'package:pubdoctor/src/cli/runner.dart';
import 'package:pubdoctor/src/environment_snapshot/environment_diff.dart';
import 'package:pubdoctor/src/environment_snapshot/environment_snapshot.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('reproducibility', () {
    test('snapshot sanitize strips secrets', () {
      final raw = {
        'dartVersion': '3.5.0',
        'api_token': 'secret',
        'nested': {'password': 'x', 'os': 'windows'},
      };
      final clean = EnvironmentSnapshotEngine.sanitize(raw);
      expect(clean.containsKey('api_token'), isFalse);
      expect((clean['nested'] as Map).containsKey('password'), isFalse);
      expect((clean['nested'] as Map)['os'], 'windows');
    });

    test('environment compare detects dart version drift', () {
      final a = EnvironmentSnapshot(
        capturedAt: DateTime.utc(2026, 1, 1),
        sdk: const SdkSnapshot(dartVersion: '3.10.1'),
        tools: const ToolSnapshot(),
        cache: const CacheSnapshot(lockfilePackageCount: 10),
        platform: const PlatformSnapshot(os: 'windows', architecture: 'x64'),
        capabilities: const ['filesystemRead'],
        lockfileHash: 'aaa',
      );
      final b = EnvironmentSnapshot(
        capturedAt: DateTime.utc(2026, 1, 2),
        sdk: const SdkSnapshot(dartVersion: '3.9.4'),
        tools: const ToolSnapshot(),
        cache: const CacheSnapshot(lockfilePackageCount: 10),
        platform: const PlatformSnapshot(os: 'windows', architecture: 'x64'),
        capabilities: const ['filesystemRead'],
        lockfileHash: 'aaa',
      );
      final diff = EnvironmentDiff.compare(a, b);
      expect(diff.entries.any((e) => e.path == 'sdk.dartVersion'), isTrue);
    });

    test('reproduce check|export cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'reproduce',
          'check',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "reproduce"'));

      final out2 = StringBuffer();
      final c2 = await runPubDoctor(
        [
          'reproduce',
          'export',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out2,
      );
      expect(c2, 0);
      expect(out2.toString(), contains('pubdoctor.reproduce.manifest'));
      expect(out2.toString().toLowerCase(), isNot(contains('password')));
    });

    test('environment snapshot cli', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'environment',
          'snapshot',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('"action": "snapshot"'));
    });
  });
}
