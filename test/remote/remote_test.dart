import 'package:pubdoctor/src/cli/runner.dart';
import 'package:pubdoctor/src/remote/remote_workspace.dart';
import 'package:pubdoctor/src/runtime/runtime_profile.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('remote / constrained', () {
    test('memory remote filesystem respects budget', () async {
      final fs = MemoryRemoteFilesystem(
        files: {'pubspec.yaml': 'name: x\n'},
        budgetBytes: 8,
      );
      expect(await fs.readText('pubspec.yaml'), isNotNull);
      expect(
        () => fs.readText('pubspec.yaml'),
        throwsA(isA<StateError>()),
      );
    });

    test('remote workspace streams essential files', () async {
      final session = RemoteSession(
        id: 's',
        uri: 'memory://demo',
        capability: const RemoteCapability(),
        filesystem: MemoryRemoteFilesystem(
          files: {
            'pubspec.yaml': 'name: demo\n',
            'pubspec.lock': 'packages: {}\n',
          },
        ),
      );
      final ws = RemoteWorkspace(session: session);
      final files = await ws.streamEssentialFiles().toList();
      expect(files, contains('pubspec.yaml'));
      expect(await ws.readPubspec(), contains('demo'));
    });

    test('minimal mode check works', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          '--minimal',
          'check',
          '--offline',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, anyOf(0, 1));
      expect(out.toString(), contains('"command": "check"'));
    });

    test('runtime profiles include remote and embeddedLike', () {
      expect(RuntimeProfileKind.values.contains(RuntimeProfileKind.remote),
          isTrue);
      expect(
        RuntimeProfileKind.values.contains(RuntimeProfileKind.embeddedLike),
        isTrue,
      );
      expect(MemoryBudget.minimal.sourceIndexBytes < 8 * 1024 * 1024, isTrue);
    });
  });
}
