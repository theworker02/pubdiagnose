import 'package:pub_semver/pub_semver.dart';
import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

void main() {
  final parser = PubspecParser();

  test('parses hosted, git, path, sdk, overrides, any', () {
    const yaml = '''
name: sources_app
version: 1.0.0+1
environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.22.0"
dependencies:
  http: ^1.2.0
  analyzer:
    hosted: https://pub.example.com
    version: ^6.0.0
  local_pkg:
    path: ../local_pkg
  from_git:
    git:
      url: https://github.com/example/from_git.git
      ref: main
      path: packages/from_git
  flutter:
    sdk: flutter
dev_dependencies:
  lints: any
dependency_overrides:
  http: 1.2.1
''';

    final doc = parser.parse(yaml);
    expect(doc.name, 'sources_app');
    expect(doc.version, Version.parse('1.0.0+1'));
    expect(doc.environment.sdk, isNotNull);
    expect(doc.environment.flutter, isNotNull);

    final http = doc.dependency('http')!;
    expect(http.source, DependencySource.hosted);
    expect(http.constraint.allows(Version.parse('1.2.0')), isTrue);

    final analyzer = doc.dependency('analyzer')!;
    expect(analyzer.hostedUrl, 'https://pub.example.com');
    expect(analyzer.constraint.toString(), '^6.0.0');

    final path = doc.dependency('local_pkg')!;
    expect(path.source, DependencySource.path);
    expect(path.path, '../local_pkg');

    final git = doc.dependency('from_git')!;
    expect(git.source, DependencySource.git);
    expect(git.gitUrl, 'https://github.com/example/from_git.git');
    expect(git.gitRef, 'main');
    expect(git.gitPath, 'packages/from_git');

    final flutter = doc.dependency('flutter')!;
    expect(flutter.source, DependencySource.sdk);
    expect(flutter.sdk, 'flutter');

    final lints = doc.devDependencies.single;
    expect(lints.constraint, VersionConstraint.any);
    expect(lints.section, DependencySection.devDependency);

    final override = doc.overrideFor('http')!;
    expect(override.section, DependencySection.override);
    expect(override.constraint, Version.parse('1.2.1'));

    expect(doc.toJson()['name'], 'sources_app');
  });

  test('throws on invalid YAML', () {
    expect(
      () => parser.parse('name: [\nbroken', source: 'bad.yaml'),
      throwsA(isA<InvalidYamlException>()),
    );
  });

  test('throws when name missing', () {
    expect(
      () => parser.parse('environment:\n  sdk: ^3.0.0'),
      throwsA(isA<InvalidProjectException>()),
    );
  });

  test('parses string git shorthand', () {
    final doc = parser.parse('''
name: g
environment:
  sdk: ^3.0.0
dependencies:
  x:
    git: https://example.com/x.git
''');
    expect(doc.dependency('x')!.gitUrl, 'https://example.com/x.git');
  });
}
