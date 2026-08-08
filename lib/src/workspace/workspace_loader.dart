import 'dart:io';

import 'package:path/path.dart' as p;

import '../graph/dependency_graph.dart';
import '../lockfile/lockfile_parser.dart';
import '../models/exceptions.dart';
import '../models/lockfile.dart';
import '../models/pubspec_document.dart';
import '../pubspec/pubspec_parser.dart';
import 'pub_cache_reader.dart';

/// A loaded Dart package workspace for analysis.
class PubWorkspace {
  /// Creates a workspace.
  PubWorkspace({
    required this.root,
    required this.pubspec,
    required this.graph,
    this.lockfile,
    this.lockfileEnriched = false,
  });

  /// Project root directory.
  final Directory root;

  /// Parsed pubspec.
  final PubspecDocument pubspec;

  /// Parsed lockfile, if present.
  final PubLockfile? lockfile;

  /// Dependency graph.
  final DependencyGraph graph;

  /// Whether lockfile edges were enriched from the pub cache.
  final bool lockfileEnriched;

  /// Absolute path to pubspec.yaml.
  String get pubspecPath => p.join(root.path, 'pubspec.yaml');

  /// Absolute path to pubspec.lock (may not exist).
  String get lockfilePath => p.join(root.path, 'pubspec.lock');

  /// Whether a lockfile was found.
  bool get hasLockfile => lockfile != null;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'root': root.path,
        'pubspec': pubspec.toJson(),
        if (lockfile != null) 'lockfile': lockfile!.toJson(),
        'hasLockfile': hasLockfile,
        'lockfileEnriched': lockfileEnriched,
        'graph': graph.toJson(),
      };
}

/// Loads and validates a [PubWorkspace].
class WorkspaceLoader {
  /// Creates a workspace loader.
  WorkspaceLoader({
    PubspecParser? pubspecParser,
    LockfileParser? lockfileParser,
    PubCacheReader? cacheReader,
    this.enrichFromCache = true,
  })  : _pubspecParser = pubspecParser ?? PubspecParser(),
        _lockfileParser = lockfileParser ?? LockfileParser(),
        _cacheReader = cacheReader ?? PubCacheReader();

  final PubspecParser _pubspecParser;
  final LockfileParser _lockfileParser;
  final PubCacheReader _cacheReader;

  /// Whether to enrich lockfile dependency maps from the pub cache.
  final bool enrichFromCache;

  /// Loads a workspace from [directory] (defaults to current directory).
  Future<PubWorkspace> load(String directory) async {
    final root = Directory(p.normalize(p.absolute(directory)));
    if (!root.existsSync()) {
      throw InvalidProjectException(
        'Directory does not exist: ${root.path}',
        code: 'PD0004',
      );
    }

    final pubspecFile = File(p.join(root.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      throw MissingPubspecException(root.path);
    }

    final pubspec = _pubspecParser.parse(pubspecFile.readAsStringSync(),
        source: pubspecFile.path);

    PubLockfile? lockfile;
    var enriched = false;
    final lockFile = File(p.join(root.path, 'pubspec.lock'));
    if (lockFile.existsSync()) {
      lockfile = _lockfileParser.parse(
        lockFile.readAsStringSync(),
        source: lockFile.path,
      );
      if (enrichFromCache) {
        final before = lockfile.packages.values
            .where((pkg) => pkg.dependencies.isNotEmpty)
            .length;
        lockfile = _cacheReader.enrich(lockfile);
        final after = lockfile.packages.values
            .where((pkg) => pkg.dependencies.isNotEmpty)
            .length;
        enriched = after > before;
      }
    }

    final graph = DependencyGraph.build(
      pubspec: pubspec,
      lockfile: lockfile,
    );

    return PubWorkspace(
      root: root,
      pubspec: pubspec,
      lockfile: lockfile,
      graph: graph,
      lockfileEnriched: enriched,
    );
  }
}
