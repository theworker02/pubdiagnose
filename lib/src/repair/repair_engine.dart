import 'dart:convert';

import '../healing/healing_policy.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../source/source_workspace.dart';
import '../workspace/workspace_loader.dart';
import 'repair_plan.dart';
import 'repair_transaction.dart';

export 'repair_plan.dart';
export 'repair_transaction.dart';

/// Provider interface for repair classes.
abstract interface class RepairProvider {
  /// Provider id.
  String get id;

  /// Propose candidates.
  Future<List<RepairCandidate>> propose(PubWorkspace workspace);
}

/// Missing direct dependency repair (T1).
class MissingDependencyRepairProvider implements RepairProvider {
  @override
  String get id => 'missing_dependency';

  @override
  Future<List<RepairCandidate>> propose(PubWorkspace workspace) async {
    final diags = SourceChecker(workspace).check();
    final byPkg = <String, List<String>>{};
    for (final d in diags) {
      if ((d.code == 'PDS101' || d.code == 'PDS102') && d.package != null) {
        byPkg.putIfAbsent(d.package!, () => []).add(d.location.path);
      }
    }
    final out = <RepairCandidate>[];
    for (final e in byPkg.entries) {
      out.add(
        RepairCandidate(
          id: 'add-dep-${e.key}',
          diagnosticCode: 'PDR102',
          description:
              'Add ${e.key} to dependencies (imported in ${e.value.length} file(s)).',
          confidence: RepairConfidence.certain,
          tier: SafetyTier.t1Metadata,
          package: e.key,
          file: e.value.first,
          operations: [
            RepairOperation(
              kind: 'add_dependency',
              target: e.key,
              detail:
                  'Add "${e.key}" with a compatible constraint to dependencies.',
            ),
          ],
        ),
      );
    }
    return out;
  }
}

/// Orchestrates repair detect → plan → transactional apply → verify.
class RepairEngine {
  /// Creates an engine.
  RepairEngine({
    required this.workspace,
    required FilesystemAdapter fs,
    required PathAdapter paths,
    List<RepairProvider>? providers,
    this.allowProcess = false,
  })  : _fs = fs,
        _paths = paths,
        providers = providers ?? [MissingDependencyRepairProvider()];

  /// Workspace.
  final PubWorkspace workspace;

  /// Providers.
  final List<RepairProvider> providers;

  /// Whether dart format/analyze may be invoked.
  final bool allowProcess;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  final List<Map<String, Object?>> _history = [];

  /// Repair history (in-memory + disk journal).
  List<Map<String, Object?>> get history => List.unmodifiable(_history);

  /// Build plan.
  Future<RepairPlan> plan({
    String? diagnosticFilter,
    String? fileFilter,
    bool safeOnly = false,
  }) async {
    final candidates = <RepairCandidate>[];
    for (final p in providers) {
      candidates.addAll(await p.propose(workspace));
    }
    var filtered = candidates;
    if (diagnosticFilter != null) {
      filtered = [
        for (final c in filtered)
          if (c.diagnosticCode == diagnosticFilter || c.id == diagnosticFilter)
            c,
      ];
    }
    if (fileFilter != null) {
      filtered = [
        for (final c in filtered)
          if (c.file == fileFilter) c,
      ];
    }
    if (safeOnly) {
      filtered = [
        for (final c in filtered)
          if (!c.ambiguous &&
              c.tier.index <= SafetyTier.t1Metadata.index &&
              (c.confidence == RepairConfidence.certain ||
                  c.confidence == RepairConfidence.high))
            c,
      ];
    }
    return RepairPlan(
      id: 'repair-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      candidates: filtered,
      summary: filtered.isEmpty
          ? 'No repairable issues detected.'
          : '${filtered.length} repairable issue(s) detected.',
    );
  }

  /// Apply plan (pubspec dependency adds only for T1).
  Future<Map<String, Object?>> apply(
    RepairPlan plan, {
    bool dryRun = false,
  }) async {
    final validator = RepairValidator();
    final staticErrors = validator.validate(plan);
    final applicable = [
      for (final c in plan.candidates)
        if (!c.ambiguous && c.tier == SafetyTier.t1Metadata) c,
    ];
    if (applicable.isEmpty) {
      return {
        'success': true,
        'applied': false,
        'dryRun': dryRun,
        'message': plan.summary ?? 'Nothing to apply',
        'staticErrors': staticErrors,
      };
    }

    if (dryRun) {
      return {
        'success': true,
        'applied': false,
        'dryRun': true,
        'candidates': [for (final c in applicable) c.toJson()],
      };
    }

    final tx = RepairTransaction(
      id: plan.id,
      rootPath: workspace.root.path,
      fs: _fs,
      paths: _paths,
    );
    tx.begin();

    final beforeCount = SourceChecker(workspace).check().length;
    const pubspecPath = 'pubspec.yaml';
    final original =
        _fs.readText(_paths.join(workspace.root.path, pubspecPath));
    if (original == null) {
      return {
        'success': false,
        'message': 'pubspec.yaml unreadable',
      };
    }

    var updated = original;
    final appliedOps = <String>[];
    for (final c in applicable) {
      for (final op in c.operations) {
        if (op.kind == 'add_dependency') {
          final name = op.target;
          if (updated.contains('\n  $name:') ||
              updated.contains('\n    $name:')) {
            continue;
          }
          updated = _insertDependency(updated, name);
          appliedOps.add('add_dependency:$name');
        }
      }
    }

    if (appliedOps.isEmpty) {
      tx.commit(success: true, message: 'No repair required (idempotent).');
      return {
        'success': true,
        'applied': false,
        'message': 'No repair required.',
      };
    }

    tx.writeFile(pubspecPath, updated);

    final afterProbe =
        applicable.every((c) => updated.contains('${c.package}:'));
    if (!afterProbe) {
      tx.rollback();
      tx.commit(success: false, message: 'dependency insert failed');
      final entry = {
        'transaction': plan.id,
        'outcome': 'rollback',
        'reason': 'verification failed',
        'ops': appliedOps,
      };
      _history.add(entry);
      _persistHistory(entry);
      return {
        'success': false,
        'applied': true,
        'rolledBack': true,
        'message': 'Repair validation failed. Changes have been rolled back.',
        'beforeSourceDiagnostics': beforeCount,
      };
    }

    tx.commit(success: true, message: 'applied ${appliedOps.length} ops');
    final entry = {
      'transaction': plan.id,
      'outcome': 'success',
      'ops': appliedOps,
      'beforeSourceDiagnostics': beforeCount,
      'filesChanged': [pubspecPath],
    };
    _history.add(entry);
    _persistHistory(entry);

    return {
      'success': true,
      'applied': true,
      'rolledBack': false,
      'ops': appliedOps,
      'message': 'Repair applied. Run dart pub get && dart analyze to verify.',
    };
  }

  String _insertDependency(String pubspec, String name) {
    final marker = RegExp(r'^dependencies:\s*$', multiLine: true);
    final match = marker.firstMatch(pubspec);
    if (match != null) {
      final insertAt = match.end;
      return '${pubspec.substring(0, insertAt)}\n  $name: any'
          '${pubspec.substring(insertAt)}';
    }
    return '$pubspec\ndependencies:\n  $name: any\n';
  }

  void _persistHistory(Map<String, Object?> entry) {
    try {
      final dir = _paths.join(
        workspace.root.path,
        '.dart_tool',
        'pubdoctor',
        'repair',
      );
      _fs.createDirectory(dir);
      final path = _paths.join(dir, 'history.jsonl');
      final existing = _fs.readText(path) ?? '';
      _fs.writeText(path, '$existing${jsonEncode(entry)}\n');
    } on Object {
      // ignore
    }
  }
}
