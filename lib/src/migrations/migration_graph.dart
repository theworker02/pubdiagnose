import 'migration_step.dart';

/// Directed graph of migration steps (prerequisite edges).
class MigrationGraph {
  /// Creates a migration graph.
  MigrationGraph(this.steps);

  /// All steps keyed by id.
  final Map<String, MigrationStep> steps;

  /// Create from a list.
  factory MigrationGraph.fromSteps(List<MigrationStep> list) {
    return MigrationGraph({for (final s in list) s.id: s});
  }

  /// Topologically ordered step ids (prerequisites first).
  ///
  /// Throws [StateError] on cycles.
  List<String> topologicalOrder() {
    final indegree = <String, int>{for (final id in steps.keys) id: 0};
    final children = <String, List<String>>{
      for (final id in steps.keys) id: [],
    };
    for (final step in steps.values) {
      for (final pre in step.prerequisiteIds) {
        if (!steps.containsKey(pre)) continue;
        children[pre]!.add(step.id);
        indegree[step.id] = (indegree[step.id] ?? 0) + 1;
      }
    }
    final queue = [
      for (final e in indegree.entries)
        if (e.value == 0) e.key,
    ]..sort();
    final order = <String>[];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      order.add(id);
      for (final child in children[id] ?? const <String>[]) {
        final next = (indegree[child] ?? 1) - 1;
        indegree[child] = next;
        if (next == 0) {
          queue.add(child);
          queue.sort();
        }
      }
    }
    if (order.length != steps.length) {
      throw StateError('Migration graph contains a cycle');
    }
    return order;
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'steps': [for (final s in steps.values) s.toJson()],
        'order': topologicalOrder(),
      };
}
