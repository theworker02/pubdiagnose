import 'package:pubdiagnose/pubdiagnose.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late PubWorkspace workspace;

  setUpAll(() async {
    workspace = await PubDoctor.load(
      fixturePath('basic_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );
  });

  test('loads pubspec and lockfile', () {
    expect(workspace.pubspec.name, 'basic_app');
    expect(workspace.hasLockfile, isTrue);
    expect(workspace.lockfile!['matcher']!.isTransitive, isTrue);
  });

  test('direct vs transitive', () {
    final direct = workspace.graph.directDependencies().map((n) => n.name);
    expect(direct, containsAll(['collection', 'path', 'test']));
    final transitive =
        workspace.graph.transitiveDependencies().map((n) => n.name).toSet();
    expect(transitive, containsAll(['matcher', 'stack_trace']));
    expect(transitive.contains('collection'), isFalse);
  });

  test('shortest path and all paths', () {
    final shortest = workspace.graph.shortestPathTo('matcher');
    expect(shortest, isNotNull);
    expect(shortest!.nodes.first, 'basic_app');
    expect(shortest.nodes.last, 'matcher');
    expect(shortest.display, contains('→'));

    final paths = workspace.graph.pathsTo('path');
    expect(paths.length, greaterThanOrEqualTo(1));
    expect(paths.any((p) => p.nodes.contains('stack_trace')), isTrue);
  });

  test('package lookup and json', () {
    expect(
        workspace.graph.package('stack_trace')?.version?.toString(), '1.11.1');
    final json = workspace.graph.toJson();
    expect(json['root'], 'basic_app');
    expect(json['tree'], isA<Map<String, Object?>>());
  });

  test('missing lockfile still loads', () async {
    final ws = await PubDoctor.load(
      fixturePath('sources_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );
    expect(ws.hasLockfile, isFalse);
    expect(ws.graph.directDependencies().map((n) => n.name), contains('http'));
  });

  test('missing pubspec throws', () async {
    expect(
      () => PubDoctor.load(fixturePath('does_not_exist_dir')),
      throwsA(isA<PubDoctorException>()),
    );
  });
}
