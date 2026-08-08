import '../../graph/dependency_graph.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor graph`
class GraphCommand extends PubDoctorCommand {
  /// Creates the command.
  GraphCommand() {
    argParser
      ..addOption(
        'package',
        help: 'Focus the tree on a package subtree.',
      )
      ..addFlag(
        'json',
        help: 'Emit JSON.',
        negatable: false,
      );
  }

  @override
  String get name => 'graph';

  @override
  String get description => 'Show the dependency graph as a tree.';

  @override
  Future<int> run() async {
    final workspace = await loadWorkspace();
    final focus = argResults!['package'] as String?;
    final graph = workspace.graph;

    if (focus != null && graph.package(focus) == null) {
      console.error('Package "$focus" not found in the graph.');
      return ExitCodes.invalid;
    }

    if (console.json) {
      console.writeJson({
        'command': 'graph',
        'project': workspace.pubspec.name,
        ...graph.toJson(focus: focus),
      });
      return ExitCodes.ok;
    }

    final root = focus ?? graph.rootName;
    console.title('Dependency graph ($root)');
    console.line();
    console.line(_label(graph, root));
    _printChildren(graph, root, '', <String>{root});
    return ExitCodes.ok;
  }

  void _printChildren(
    DependencyGraph graph,
    String parent,
    String indent,
    Set<String> stack,
  ) {
    final children = graph.childrenOf(parent);
    for (var i = 0; i < children.length; i++) {
      final name = children[i];
      final isLast = i == children.length - 1;
      final connector = isLast ? '└─ ' : '├─ ';
      final label = _label(graph, name);
      if (stack.contains(name)) {
        console.line('$indent$connector$label ↩ cycle');
        continue;
      }
      console.line('$indent$connector$label');
      stack.add(name);
      _printChildren(
        graph,
        name,
        '$indent${isLast ? '   ' : '│  '}',
        stack,
      );
      stack.remove(name);
    }
  }

  String _label(DependencyGraph graph, String name) {
    final node = graph.package(name);
    final buffer = StringBuffer(name);
    if (node?.version != null) buffer.write(' @ ${node!.version}');
    if (node?.dependencyKind != null) {
      buffer.write(' (${node!.dependencyKind})');
    }
    return buffer.toString();
  }
}
