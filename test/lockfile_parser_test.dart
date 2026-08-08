import 'package:pub_semver/pub_semver.dart';
import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

void main() {
  final parser = LockfileParser();

  test('parses packages, sdks, checksum, dependencies', () {
    const yaml = '''
version: 3
sdks:
  dart: ">=3.5.0 <4.0.0"
packages:
  path:
    dependency: "direct main"
    description:
      name: path
      sha256: abc123
      url: "https://pub.dev"
    source: hosted
    version: "1.9.0"
    dependencies:
      meta: ^1.0.0
''';
    final lock = parser.parse(yaml);
    expect(lock.lockfileVersion, 3);
    expect(lock.sdks['dart'], '>=3.5.0 <4.0.0');
    final path = lock['path']!;
    expect(path.version, Version.parse('1.9.0'));
    expect(path.isDirectMain, isTrue);
    expect(path.sha256, 'abc123');
    expect(path.dependencies['meta'], '^1.0.0');
    expect(path.toJson()['version'], '1.9.0');
  });

  test('throws on invalid YAML', () {
    expect(
      () => parser.parse('{[', source: 'lock'),
      throwsA(isA<InvalidYamlException>()),
    );
  });

  test('throws on missing package version', () {
    expect(
      () => parser.parse('''
packages:
  x:
    dependency: transitive
    source: hosted
    description:
      name: x
'''),
      throwsA(isA<InvalidProjectException>()),
    );
  });
}
