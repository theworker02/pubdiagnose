import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../incremental/incremental_engine.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../workspace/workspace_loader.dart';

/// Integrity event.
class IntegrityEvent {
  /// Creates an event.
  const IntegrityEvent({
    required this.path,
    required this.kind,
    required this.at,
  });

  /// Path.
  final String path;

  /// Kind: modified / added / removed.
  final String kind;

  /// Timestamp.
  final DateTime at;

  /// JSON.
  Map<String, Object?> toJson() => {
        'path': path,
        'kind': kind,
        'at': at.toUtc().toIso8601String(),
      };
}

/// Integrity fingerprint (not a security guarantee).
class IntegrityState {
  /// Creates state.
  const IntegrityState({
    required this.fingerprint,
    required this.at,
  });

  /// Fingerprint digest.
  final String fingerprint;

  /// When taken.
  final DateTime at;

  /// JSON.
  Map<String, Object?> toJson() => {
        'fingerprint': fingerprint,
        'at': at.toUtc().toIso8601String(),
      };
}

/// Diff between integrity states.
class IntegrityDiff {
  /// Creates a diff.
  const IntegrityDiff({
    required this.changedParts,
    required this.events,
  });

  /// Changed fingerprint parts.
  final List<String> changedParts;

  /// Events.
  final List<IntegrityEvent> events;

  /// JSON.
  Map<String, Object?> toJson() => {
        'changedParts': changedParts,
        'events': [for (final e in events) e.toJson()],
      };
}

/// Continuous integrity monitor helpers.
class IntegrityEngine {
  /// Creates an engine.
  IntegrityEngine({
    required this.workspace,
    required FilesystemAdapter fs,
    required PathAdapter paths,
  })  : _fs = fs,
        _paths = paths,
        _incremental = IncrementalEngine(
          workspace: workspace,
          fs: fs,
          paths: paths,
        );

  /// Workspace.
  final PubWorkspace workspace;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;
  final IncrementalEngine _incremental;

  IntegrityState? _last;

  /// Current fingerprint state.
  IntegrityState snapshot() {
    final plan = _incremental.plan();
    final fp = (plan['fingerprint'] as Map?)?['digest']?.toString() ?? '';
    final state = IntegrityState(fingerprint: fp, at: DateTime.now().toUtc());
    _last = state;
    return state;
  }

  /// Diff vs last snapshot.
  IntegrityDiff? diff() {
    final prev = _last;
    final nextPlan = _incremental.plan();
    final changed = [
      for (final e in (nextPlan['changedParts'] as List? ?? const []))
        e.toString(),
    ];
    final events = [
      for (final c in changed)
        IntegrityEvent(
          path: c,
          kind: 'modified',
          at: DateTime.now().toUtc(),
        ),
    ];
    if (prev == null && changed.isEmpty) return null;
    return IntegrityDiff(changedParts: changed, events: events);
  }

  /// Watch key files; yields events. Cancel the subscription to stop.
  Stream<IntegrityEvent> watch({
    Duration pollInterval = const Duration(seconds: 1),
    void Function()? onTick,
  }) {
    // StreamController is closed when the subscription is cancelled.
    // ignore: close_sinks
    late final StreamController<IntegrityEvent> controller;
    final watched = [
      p.join(workspace.root.path, 'pubspec.yaml'),
      p.join(workspace.root.path, 'pubspec.lock'),
      p.join(workspace.root.path, 'pubdoctor.yaml'),
      p.join(workspace.root.path, '.pubdoctor.yaml'),
    ];
    final mtimes = <String, DateTime?>{
      for (final w in watched) w: _mtime(w),
    };

    Timer? timer;
    controller = StreamController<IntegrityEvent>(
      onListen: () {
        timer = Timer.periodic(pollInterval, (_) {
          onTick?.call();
          for (final path in watched) {
            final next = _mtime(path);
            final prev = mtimes[path];
            if (prev != next) {
              mtimes[path] = next;
              final kind = next == null
                  ? 'removed'
                  : prev == null
                      ? 'added'
                      : 'modified';
              if (!controller.isClosed) {
                controller.add(
                  IntegrityEvent(
                    path: p.relative(path, from: workspace.root.path),
                    kind: kind,
                    at: DateTime.now().toUtc(),
                  ),
                );
              }
            }
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  DateTime? _mtime(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return f.lastModifiedSync();
    } on Object {
      return null;
    }
  }

  // silence unused fields when tree-shaken oddly
  FilesystemAdapter get fs => _fs;
  PathAdapter get paths => _paths;
}
