import 'dart:convert';

import '../cache/cache_store.dart';
import '../models/diagnostics.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../risk/risk_report.dart';
import '../serialization/schema_version.dart';
import '../workspace/workspace_loader.dart';

/// A point-in-time project intelligence snapshot.
class ProjectSnapshot {
  /// Creates a snapshot.
  ProjectSnapshot({
    required this.id,
    required this.createdAt,
    required this.projectName,
    required this.payload,
    this.label,
    this.gitHead,
  });

  /// Snapshot id.
  final String id;

  /// Optional label.
  final String? label;

  /// Creation time.
  final DateTime createdAt;

  /// Project name.
  final String projectName;

  /// Optional git HEAD (never required).
  final String? gitHead;

  /// Snapshot payload.
  final Map<String, Object?> payload;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': SchemaVersions.snapshots,
        'id': id,
        if (label != null) 'label': label,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'projectName': projectName,
        if (gitHead != null) 'gitHead': gitHead,
        'payload': payload,
      };

  /// Parse from JSON.
  factory ProjectSnapshot.fromJson(Map<String, Object?> json) {
    return ProjectSnapshot(
      id: json['id']! as String,
      label: json['label'] as String?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      projectName: json['projectName']! as String,
      gitHead: json['gitHead'] as String?,
      payload: Map<String, Object?>.from(json['payload'] as Map? ?? {}),
    );
  }
}

/// Result of comparing two snapshots.
class SnapshotDiff {
  /// Creates a diff.
  const SnapshotDiff({
    required this.fromId,
    required this.toId,
    required this.changes,
    this.diagnostics = const [],
  });

  /// Older snapshot id.
  final String fromId;

  /// Newer snapshot id.
  final String toId;

  /// Human-readable change lines.
  final List<String> changes;

  /// Drift diagnostics.
  final List<Diagnostic> diagnostics;

  /// Whether any drift was detected.
  bool get hasDrift => changes.isNotEmpty;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': SchemaVersions.snapshots,
        'fromId': fromId,
        'toId': toId,
        'hasDrift': hasDrift,
        'changes': changes,
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };
}

/// Persists project snapshots under `.dart_tool/pubdoctor/snapshots/`.
class SnapshotStore {
  /// Creates a store.
  SnapshotStore(this.cache, {FilesystemAdapter? fs, PathAdapter? paths})
      : _fs = fs ?? cache.fs,
        _paths = paths ?? cache.paths;

  /// Cache root.
  final CacheStore cache;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  /// Snapshots directory.
  String get snapshotsDir => _paths.join(cache.rootPath, 'snapshots');

  /// Ensure layout.
  void ensureLayout() {
    cache.ensureLayout();
    _fs.createDirectory(snapshotsDir);
    final marker = _paths.join(snapshotsDir, 'schema.json');
    if (!_fs.fileExists(marker)) {
      _fs.writeText(
        marker,
        '${jsonEncode({'schemaVersion': SchemaVersions.snapshots})}\n',
      );
    }
  }

  /// Capture a snapshot from [workspace] (+ optional risk).
  ProjectSnapshot create(
    PubWorkspace workspace, {
    String? label,
    String? gitHead,
    RiskReport? risk,
    List<Diagnostic>? diagnostics,
  }) {
    ensureLayout();
    final id =
        'snap-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}';
    final lockPackages = <String, String>{};
    if (workspace.lockfile != null) {
      for (final e in workspace.lockfile!.packages.entries) {
        lockPackages[e.key] = e.value.version.toString();
      }
    }
    final payload = <String, Object?>{
      'sdk': workspace.pubspec.environment.sdk?.toString(),
      'flutter': workspace.pubspec.environment.flutter?.toString(),
      'directDependencies': {
        for (final d in workspace.pubspec.dependencies)
          d.name: d.constraint.toString(),
      },
      'devDependencies': {
        for (final d in workspace.pubspec.devDependencies)
          d.name: d.constraint.toString(),
      },
      'overrides': {
        for (final d in workspace.pubspec.dependencyOverrides)
          d.name: d.constraint.toString(),
      },
      'lockPackages': lockPackages,
      if (diagnostics != null)
        'diagnosticCodes': [
          for (final d in diagnostics) '${d.code}:${d.package ?? ''}',
        ]..sort(),
      if (risk != null)
        'risk': {
          'worstCategory': risk.worstCategory.name,
          'signalIds': [for (final s in risk.signals) s.id]..sort(),
        },
      'workspace': {
        'packageCount': workspace.graph.packages.length,
        'hasLockfile': workspace.hasLockfile,
      },
    };

    final snap = ProjectSnapshot(
      id: id,
      label: label,
      createdAt: DateTime.now().toUtc(),
      projectName: workspace.pubspec.name,
      gitHead: gitHead,
      payload: payload,
    );
    final path = _paths.join(snapshotsDir, '$id.json');
    _fs.writeText(
      path,
      '${const JsonEncoder.withIndent('  ').convert(snap.toJson())}\n',
    );
    return snap;
  }

  /// List snapshots newest first.
  List<ProjectSnapshot> list() {
    ensureLayout();
    final out = <ProjectSnapshot>[];
    for (final entity in _fs.listDirectory(snapshotsDir)) {
      final name = _paths.basename(entity.path);
      if (!name.endsWith('.json') || name == 'schema.json') continue;
      final raw = _fs.readText(entity.path);
      if (raw == null) continue;
      try {
        out.add(
          ProjectSnapshot.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          ),
        );
      } on Object {
        continue;
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Load by id.
  ProjectSnapshot? get(String id) {
    ensureLayout();
    final raw = _fs.readText(_paths.join(snapshotsDir, '$id.json'));
    if (raw == null) return null;
    try {
      return ProjectSnapshot.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  /// Compare two snapshots.
  SnapshotDiff compare(ProjectSnapshot from, ProjectSnapshot to) {
    final changes = <String>[];
    void diffMap(String label, Object? a, Object? b) {
      if (a == b) return;
      if (a is Map && b is Map) {
        final keys = {
          ...a.keys.map((k) => k.toString()),
          ...b.keys.map((k) => k.toString())
        };
        for (final k in keys) {
          if (a[k]?.toString() != b[k]?.toString()) {
            changes.add('$label.$k: ${a[k]} → ${b[k]}');
          }
        }
      } else if (a is List && b is List) {
        final as = a.map((e) => e.toString()).toSet();
        final bs = b.map((e) => e.toString()).toSet();
        for (final x in bs.difference(as)) {
          changes.add('$label: +$x');
        }
        for (final x in as.difference(bs)) {
          changes.add('$label: -$x');
        }
      } else {
        changes.add('$label: $a → $b');
      }
    }

    final a = from.payload;
    final b = to.payload;
    for (final key in {...a.keys, ...b.keys}) {
      diffMap(key, a[key], b[key]);
    }

    final diagnostics = <Diagnostic>[
      if (changes.isNotEmpty)
        Diagnostic(
          code: DiagnosticCodes.snapshotDrift,
          title: 'Snapshot drift',
          message:
              '${changes.length} change(s) between ${from.id} and ${to.id}.',
          severity: DiagnosticSeverity.warning,
          evidence: changes.take(20).toList(),
        ),
    ];

    return SnapshotDiff(
      fromId: from.id,
      toId: to.id,
      changes: changes,
      diagnostics: diagnostics,
    );
  }

  /// Drift current workspace vs latest (or [baselineId]) snapshot.
  SnapshotDiff? drift(
    PubWorkspace workspace, {
    String? baselineId,
    RiskReport? risk,
    List<Diagnostic>? diagnostics,
  }) {
    final snaps = list();
    if (snaps.isEmpty) return null;
    final baseline = baselineId != null ? get(baselineId) : snaps.first;
    if (baseline == null) return null;
    final current = create(
      workspace,
      label: 'drift-temp',
      risk: risk,
      diagnostics: diagnostics,
    );
    // Remove temp file — compare in memory.
    try {
      _fs.deleteFile(_paths.join(snapshotsDir, '${current.id}.json'));
    } on Object {
      // ignore
    }
    return compare(baseline, current);
  }
}
