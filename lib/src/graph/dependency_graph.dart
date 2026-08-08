import 'package:pub_semver/pub_semver.dart';

import '../models/graph_models.dart';
import '../models/lockfile.dart';
import '../models/pubspec_document.dart';

/// In-memory dependency graph built from pubspec + lockfile.
class DependencyGraph {
  DependencyGraph._({
    required Map<String, PackageNode> nodes,
    required List<DependencyEdge> edges,
    required Map<String, List<String>> children,
    required Map<String, List<String>> parents,
    required String rootName,
  })  : _nodes = nodes,
        _edges = edges,
        _children = children,
        _parents = parents,
        _rootName = rootName;

  final Map<String, PackageNode> _nodes;
  final List<DependencyEdge> _edges;
  final Map<String, List<String>> _children;
  final Map<String, List<String>> _parents;
  final String _rootName;

  /// Synthetic root package name (the project's package name).
  String get rootName => _rootName;

  /// All package nodes including root.
  Iterable<PackageNode> get packages => _nodes.values;

  /// Lookup a package by name.
  PackageNode? package(String name) => _nodes[name];

  /// All edges.
  List<DependencyEdge> get edges => List.unmodifiable(_edges);

  /// Direct dependencies of the root.
  Iterable<PackageNode> directDependencies() {
    final kids = _children[_rootName] ?? const <String>[];
    return kids.map((n) => _nodes[n]).whereType<PackageNode>();
  }

  /// Transitive packages (everything except root and its direct deps).
  Iterable<PackageNode> transitiveDependencies() {
    final direct = {
      for (final n in directDependencies()) n.name,
    };
    return _nodes.values.where(
      (n) => !n.isRoot && !direct.contains(n.name),
    );
  }

  /// Parents of [name].
  Iterable<PackageNode> ancestors(String name) {
    final seen = <String>{};
    final result = <PackageNode>[];
    final queue = [...(_parents[name] ?? const <String>[])];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!seen.add(current)) continue;
      final node = _nodes[current];
      if (node != null && !node.isRoot) result.add(node);
      queue.addAll(_parents[current] ?? const <String>[]);
    }
    return result;
  }

  /// Descendants of [name].
  Iterable<PackageNode> descendants(String name) {
    final seen = <String>{};
    final result = <PackageNode>[];
    final queue = [...(_children[name] ?? const <String>[])];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!seen.add(current)) continue;
      final node = _nodes[current];
      if (node != null) result.add(node);
      queue.addAll(_children[current] ?? const <String>[]);
    }
    return result;
  }

  /// Shortest path from root to [package] (BFS). Null if unreachable.
  DependencyPath? shortestPathTo(String package) {
    if (!_nodes.containsKey(package)) return null;
    if (package == _rootName) {
      return DependencyPath([_rootName]);
    }

    final parentOf = <String, String>{};
    final queue = <String>[_rootName];
    final visited = <String>{_rootName};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final child in _children[current] ?? const <String>[]) {
        if (!visited.add(child)) continue;
        parentOf[child] = current;
        if (child == package) {
          return _reconstructPath(package, parentOf);
        }
        queue.add(child);
      }
    }
    return null;
  }

  /// All simple paths from root to [package]. Cycles are skipped.
  List<DependencyPath> pathsTo(String package, {int? limit}) {
    if (!_nodes.containsKey(package)) return const [];
    if (package == _rootName) {
      return [
        DependencyPath([_rootName])
      ];
    }

    final results = <DependencyPath>[];
    void dfs(String current, List<String> path, Set<String> onStack) {
      if (limit != null && results.length >= limit) return;
      if (current == package) {
        results.add(_pathFromNodes(path));
        return;
      }
      for (final child in _children[current] ?? const <String>[]) {
        if (onStack.contains(child)) continue;
        path.add(child);
        onStack.add(child);
        dfs(child, path, onStack);
        onStack.remove(child);
        path.removeLast();
      }
    }

    dfs(_rootName, [_rootName], {_rootName});
    return results;
  }

  /// Edge between [from] and [to], if any.
  DependencyEdge? edge(String from, String to) {
    for (final e in _edges) {
      if (e.from == from && e.to == to) return e;
    }
    return null;
  }

  /// Children names of [name].
  List<String> childrenOf(String name) =>
      List.unmodifiable(_children[name] ?? const <String>[]);

  /// Parent names of [name].
  List<String> parentsOf(String name) =>
      List.unmodifiable(_parents[name] ?? const <String>[]);

  /// Tree-oriented map for JSON serialization.
  Map<String, Object?> toJson({String? focus}) {
    final root = focus ?? _rootName;
    return {
      'root': _rootName,
      'packages': [
        for (final n in _nodes.values) n.toJson(),
      ],
      'edges': [for (final e in _edges) e.toJson()],
      'tree': _treeJson(root, <String>{}),
    };
  }

  Map<String, Object?> _treeJson(String name, Set<String> stack) {
    final node = _nodes[name];
    final children = <Map<String, Object?>>[];
    if (!stack.contains(name)) {
      stack.add(name);
      for (final child in _children[name] ?? const <String>[]) {
        children.add(_treeJson(child, stack));
      }
      stack.remove(name);
    } else {
      return {
        'name': name,
        'cycle': true,
        if (node?.version != null) 'version': node!.version.toString(),
      };
    }
    return {
      'name': name,
      if (node?.version != null) 'version': node!.version.toString(),
      if (node?.dependencyKind != null) 'dependencyKind': node!.dependencyKind,
      'dependencies': children,
    };
  }

  DependencyPath _reconstructPath(
    String target,
    Map<String, String> parentOf,
  ) {
    final nodes = <String>[target];
    var current = target;
    while (parentOf.containsKey(current)) {
      current = parentOf[current]!;
      nodes.add(current);
    }
    return _pathFromNodes(nodes.reversed.toList());
  }

  DependencyPath _pathFromNodes(List<String> nodes) {
    final edges = <DependencyEdge>[];
    for (var i = 0; i < nodes.length - 1; i++) {
      edges.add(
        edge(nodes[i], nodes[i + 1]) ??
            DependencyEdge(from: nodes[i], to: nodes[i + 1]),
      );
    }
    return DependencyPath(List.unmodifiable(nodes), edges: edges);
  }

  /// Builds a graph from [pubspec] and optional [lockfile].
  static DependencyGraph build({
    required PubspecDocument pubspec,
    PubLockfile? lockfile,
  }) {
    final rootName = pubspec.name;
    final nodes = <String, PackageNode>{
      rootName: PackageNode(name: rootName, isRoot: true),
    };
    final edges = <DependencyEdge>[];
    final children = <String, List<String>>{rootName: []};
    final parents = <String, List<String>>{};

    void ensureNode(PackageNode node) {
      nodes.putIfAbsent(node.name, () => node);
      children.putIfAbsent(node.name, () => []);
      parents.putIfAbsent(node.name, () => []);
    }

    void addEdge(String from, String to, VersionConstraint? constraint) {
      ensureNode(
        nodes[to] ?? PackageNode(name: to),
      );
      children.putIfAbsent(from, () => []);
      parents.putIfAbsent(to, () => []);
      if (!(children[from]!.contains(to))) {
        children[from]!.add(to);
      }
      if (!(parents[to]!.contains(from))) {
        parents[to]!.add(from);
      }
      // Prefer first constraint; skip duplicate edges.
      final exists = edges.any((e) => e.from == from && e.to == to);
      if (!exists) {
        edges.add(DependencyEdge(from: from, to: to, constraint: constraint));
      }
    }

    // Root → direct dependencies from pubspec.
    for (final spec in [
      ...pubspec.dependencies,
      ...pubspec.devDependencies,
    ]) {
      final locked = lockfile?[spec.name];
      ensureNode(
        PackageNode(
          name: spec.name,
          version: locked?.version,
          dependencyKind: locked?.dependency,
          source: spec.source,
          spec: spec,
          locked: locked,
        ),
      );
      addEdge(rootName, spec.name, spec.constraint);
    }

    // Also include overrides as nodes (not always edged from root unless also deps).
    for (final spec in pubspec.dependencyOverrides) {
      final locked = lockfile?[spec.name];
      final existing = nodes[spec.name];
      if (existing == null) {
        ensureNode(
          PackageNode(
            name: spec.name,
            version: locked?.version,
            dependencyKind: locked?.dependency,
            source: spec.source,
            spec: spec,
            locked: locked,
          ),
        );
      }
    }

    if (lockfile != null) {
      for (final locked in lockfile.packages.values) {
        final existing = nodes[locked.name];
        if (existing == null) {
          ensureNode(
            PackageNode(
              name: locked.name,
              version: locked.version,
              dependencyKind: locked.dependency,
              source: locked.dependencySource,
              locked: locked,
            ),
          );
        } else if (existing.version == null) {
          nodes[locked.name] = PackageNode(
            name: locked.name,
            version: locked.version,
            dependencyKind: locked.dependency,
            source: existing.source ?? locked.dependencySource,
            spec: existing.spec,
            locked: locked,
          );
        }

        // Edges from lockfile package dependencies when present.
        if (locked.dependencies.isNotEmpty) {
          for (final entry in locked.dependencies.entries) {
            VersionConstraint? constraint;
            try {
              constraint = VersionConstraint.parse(entry.value);
            } on FormatException {
              constraint = VersionConstraint.any;
            }
            final childLocked = lockfile[entry.key];
            ensureNode(
              PackageNode(
                name: entry.key,
                version: childLocked?.version,
                dependencyKind: childLocked?.dependency,
                source: childLocked?.dependencySource,
                locked: childLocked,
              ),
            );
            addEdge(locked.name, entry.key, constraint);
          }
        }
      }

      // When lockfile packages lack per-package dependency maps (common in
      // older or simplified fixtures), connect transitive packages to all
      // direct packages is wrong. Instead, if a package has no parents yet
      // and is transitive, attach it under every direct dependency that could
      // explain it only via unknown edges — better: attach under a synthetic
      // approach using dependency kind.
      //
      // Practical fallback: if a transitive package has no incoming edges,
      // leave it orphaned but still listed; path queries return empty. For
      // fixtures we include dependency maps. Additionally, connect direct
      // overridden packages from root if missing.
      for (final locked in lockfile.packages.values) {
        if ((locked.isDirectMain ||
                locked.isDirectDev ||
                locked.isOverridden) &&
            !(children[rootName] ?? const []).contains(locked.name)) {
          final spec = pubspec.dependency(locked.name) ??
              pubspec.overrideFor(locked.name);
          addEdge(rootName, locked.name, spec?.constraint);
        }
      }
    }

    return DependencyGraph._(
      nodes: nodes,
      edges: edges,
      children: children,
      parents: parents,
      rootName: rootName,
    );
  }
}
