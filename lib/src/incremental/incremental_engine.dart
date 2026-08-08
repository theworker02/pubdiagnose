import 'dart:convert';

import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../workspace/workspace_loader.dart';

/// Fingerprint of dependency-related inputs.
class DependencyFingerprint {
  /// Creates a fingerprint.
  const DependencyFingerprint({
    required this.digest,
    required this.parts,
  });

  /// Combined digest.
  final String digest;

  /// Named part digests.
  final Map<String, String> parts;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'digest': digest,
        'parts': parts,
      };
}

/// Detects which analysis inputs changed.
class ChangeDetector {
  /// Creates a detector.
  ChangeDetector({
    required FilesystemAdapter fs,
    required PathAdapter paths,
  })  : _fs = fs,
        _paths = paths;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  /// Fingerprint workspace inputs.
  DependencyFingerprint fingerprint(PubWorkspace workspace) {
    final root = workspace.root.path;
    final parts = <String, String>{
      'pubspec': _fileDigest(_paths.join(root, 'pubspec.yaml')),
      'lock': _fileDigest(_paths.join(root, 'pubspec.lock')),
      'config': _fileDigest(_paths.join(root, 'pubdoctor.yaml')),
      'configDot': _fileDigest(_paths.join(root, '.pubdoctor.yaml')),
      'graph': _hash(jsonEncode({
        'packages': workspace.graph.packages.length,
        'edges': workspace.graph.edges.length,
      })),
    };
    final combined =
        _hash(parts.entries.map((e) => '${e.key}=${e.value}').join('|'));
    return DependencyFingerprint(digest: combined, parts: parts);
  }

  /// Which part keys differ between fingerprints.
  List<String> changedParts(
    DependencyFingerprint previous,
    DependencyFingerprint next,
  ) {
    final keys = {...previous.parts.keys, ...next.parts.keys};
    return [
      for (final k in keys)
        if (previous.parts[k] != next.parts[k]) k,
    ]..sort();
  }

  String _fileDigest(String path) {
    final text = _fs.readText(path);
    if (text == null) return 'missing';
    return _hash(text);
  }

  String _hash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

/// Maps input parts to analyzers that must re-run.
class InvalidationGraph {
  /// Default invalidation edges: input → analyzers.
  static const Map<String, List<String>> edges = {
    'pubspec': [
      'constraints',
      'overrides',
      'unused',
      'imports',
      'risk',
      'policy'
    ],
    'lock': ['graph', 'outdated', 'risk', 'impact'],
    'config': ['policy', 'check'],
    'configDot': ['policy', 'check'],
    'graph': ['impact', 'risk', 'why'],
  };

  /// Analyzers invalidated by [changedParts].
  static Set<String> invalidate(Iterable<String> changedParts) {
    final out = <String>{};
    for (final part in changedParts) {
      out.addAll(edges[part] ?? const []);
    }
    return out;
  }
}

/// Timing entry for profiling.
class ProfileTiming {
  /// Creates a timing.
  const ProfileTiming({
    required this.name,
    required this.milliseconds,
  });

  /// Step name.
  final String name;

  /// Duration ms.
  final int milliseconds;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        'ms': milliseconds,
      };
}

/// Incremental / performance analysis helper.
class IncrementalEngine {
  /// Creates an engine.
  IncrementalEngine({
    required this.workspace,
    required FilesystemAdapter fs,
    required PathAdapter paths,
    this.largeWorkspace = false,
    this.maxParallel = 4,
  }) : _detector = ChangeDetector(fs: fs, paths: paths);

  /// Workspace.
  final PubWorkspace workspace;

  /// Large workspace mode — tighter path limits.
  final bool largeWorkspace;

  /// Bound on parallel analyzer slots (advisory).
  final int maxParallel;

  final ChangeDetector _detector;

  DependencyFingerprint? _previous;

  /// Compute current fingerprint and invalidation set.
  Map<String, Object?> plan() {
    final next = _detector.fingerprint(workspace);
    final changed = _previous == null
        ? next.parts.keys.toList()
        : _detector.changedParts(_previous!, next);
    final invalidated = InvalidationGraph.invalidate(changed);
    _previous = next;
    return {
      'fingerprint': next.toJson(),
      'changedParts': changed,
      'invalidatedAnalyzers': invalidated.toList()..sort(),
      'largeWorkspace': largeWorkspace,
      'maxParallel': maxParallel,
      'pathExpansionLimit': largeWorkspace ? 8 : 32,
    };
  }

  /// Run a profiled set of local steps (no network).
  Future<Map<String, Object?>> profile({
    required Future<void> Function(String name) runStep,
    List<String> steps = const [
      'load',
      'constraints',
      'graph',
      'imports',
      'unused',
    ],
  }) async {
    final timings = <ProfileTiming>[];
    final swTotal = Stopwatch()..start();
    for (final step in steps) {
      final sw = Stopwatch()..start();
      await runStep(step);
      timings
          .add(ProfileTiming(name: step, milliseconds: sw.elapsedMilliseconds));
    }
    return {
      'schemaVersion': 1,
      'totalMs': swTotal.elapsedMilliseconds,
      'timings': [for (final t in timings) t.toJson()],
      'plan': plan(),
      'budgets': {
        'checkLocalMs': 5000,
        'graphMs': 2000,
        'importsMs': 3000,
      },
    };
  }
}
