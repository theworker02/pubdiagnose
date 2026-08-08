import 'package:pub_semver/pub_semver.dart';

import 'dependency_spec.dart';
import 'lockfile.dart';

/// A node in the dependency graph.
class PackageNode {
  /// Creates a package node.
  PackageNode({
    required this.name,
    this.version,
    this.dependencyKind,
    this.source,
    this.isRoot = false,
    this.spec,
    this.locked,
  });

  /// Package name (`(root)` for the workspace root).
  final String name;

  /// Resolved version when known.
  final Version? version;

  /// Lockfile dependency classification when known.
  final String? dependencyKind;

  /// Source kind when known.
  final DependencySource? source;

  /// Whether this is the synthetic root node.
  final bool isRoot;

  /// Declared pubspec spec when this is a direct root dependency.
  final DependencySpec? spec;

  /// Lockfile entry when present.
  final LockedPackage? locked;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        if (version != null) 'version': version.toString(),
        if (dependencyKind != null) 'dependencyKind': dependencyKind,
        if (source != null) 'source': source!.name,
        'isRoot': isRoot,
      };

  @override
  String toString() =>
      isRoot ? '(root)' : '$name${version != null ? '@$version' : ''}';
}

/// A directed dependency edge with optional version constraint.
class DependencyEdge {
  /// Creates an edge from [from] to [to].
  const DependencyEdge({
    required this.from,
    required this.to,
    this.constraint,
  });

  /// Dependent package.
  final String from;

  /// Dependency package.
  final String to;

  /// Constraint applied by [from] on [to], when known.
  final VersionConstraint? constraint;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'from': from,
        'to': to,
        if (constraint != null) 'constraint': constraint.toString(),
      };
}

/// A path from the root (or another start) to a target package.
class DependencyPath {
  /// Creates a dependency path.
  const DependencyPath(this.nodes, {this.edges = const []});

  /// Ordered package names from start to target (inclusive).
  final List<String> nodes;

  /// Edges along the path (length is typically `nodes.length - 1`).
  final List<DependencyEdge> edges;

  /// Number of hops.
  int get length => nodes.isEmpty ? 0 : nodes.length - 1;

  /// Target package name.
  String get target => nodes.isEmpty ? '' : nodes.last;

  /// Human-readable path (`a → b → c`).
  String get display => nodes.join(' → ');

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'nodes': nodes,
        'length': length,
        'display': display,
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => display;
}
