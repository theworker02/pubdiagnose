import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('handles cycles without hanging', () async {
    final ws = await PubDoctor.load(
      fixturePath('cycle_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );

    final paths = ws.graph.pathsTo('c');
    expect(paths, isNotEmpty);
    expect(paths.first.nodes.contains('a'), isTrue);

    // Tree JSON should mark cycles instead of infinite recursion.
    final tree = ws.graph.toJson()['tree'] as Map<String, Object?>;
    expect(tree['name'], 'cycle_app');

    final descendants = ws.graph.descendants('a').map((n) => n.name).toSet();
    expect(descendants, containsAll(['b', 'c']));
  });
}
