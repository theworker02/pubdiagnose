import 'package:args/command_runner.dart';

import '../../models/exceptions.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor why <package>`
class WhyCommand extends PubDoctorCommand {
  /// Creates the command.
  WhyCommand() {
    argParser
      ..addFlag(
        'all',
        help: 'Show all paths, not only the shortest.',
        negatable: false,
      )
      ..addFlag(
        'json',
        help: 'Emit JSON.',
        negatable: false,
      );
  }

  @override
  String get name => 'why';

  @override
  String get description =>
      'Explain why a package is installed (dependency paths from the root).';

  @override
  String get invocation => 'pubdoctor why <package> [--all] [--json]';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Missing package name.', usage);
    }
    final package = argResults!.rest.first;
    final showAll = argResults!['all'] == true;
    final workspace = await loadWorkspace();
    final graph = workspace.graph;
    final node = graph.package(package);

    if (node == null) {
      throw InvalidProjectException(
        'Package "$package" was not found in the dependency graph. '
        'Is it in pubspec.yaml / pubspec.lock?',
        code: 'PD1201',
      );
    }

    final shortest = graph.shortestPathTo(package);
    final allPaths = graph.pathsTo(package);
    final paths = showAll
        ? allPaths
        : [
            if (shortest != null) shortest,
          ];

    if (console.json) {
      console.writeJson({
        'command': 'why',
        'package': package,
        'version': node.version?.toString(),
        'dependencyKind': node.dependencyKind,
        'shortestPath': shortest?.toJson(),
        'pathCount': allPaths.length,
        'paths': [for (final p in paths) p.toJson()],
      });
      return shortest == null ? ExitCodes.diagnostics : ExitCodes.ok;
    }

    console.title(
      'Why $package${node.version != null ? ' @ ${node.version}' : ''}',
    );
    if (node.dependencyKind != null) {
      console.muted('Kind: ${node.dependencyKind}');
    }

    if (shortest == null) {
      console.warning(
        'No path from project root to $package. It may be an orphaned lockfile '
        'entry or only present via an override.',
      );
      return ExitCodes.diagnostics;
    }

    console.line();
    console.line('Shortest path (${shortest.length} hop(s)):');
    console.path(shortest, prefix: '  ');

    console.line();
    console.muted('${allPaths.length} path(s) from root to $package.');

    if (showAll) {
      console.line();
      console.line('All paths:');
      for (final p in allPaths) {
        console.path(p, prefix: '  ');
      }
    }

    return ExitCodes.ok;
  }
}
