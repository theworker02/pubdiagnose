import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('PubDoctor.load loads fixture workspace', () async {
    final workspace = await PubDoctor.load(
      fixturePath('basic_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );
    expect(workspace.pubspec.name, 'basic_app');
    expect(workspace.hasLockfile, isTrue);
    expect(workspace.graph.package('collection'), isNotNull);
  });

  test('package version constant is non-empty', () {
    expect(pubdoctorPackageVersion, isNotEmpty);
  });
}
