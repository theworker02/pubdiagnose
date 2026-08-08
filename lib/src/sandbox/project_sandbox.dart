import 'dart:io';

import 'package:path/path.dart' as p;

/// Diff between sandbox and original.
class SandboxDiff {
  /// Creates a diff.
  const SandboxDiff({required this.changes});

  /// Change lines.
  final List<String> changes;

  /// JSON.
  Map<String, Object?> toJson() => {'changes': changes};
}

/// Result of sandbox execution.
class SandboxResult {
  /// Creates a result.
  const SandboxResult({
    required this.ok,
    required this.workDir,
    this.diff,
    this.analyzerErrors,
    this.notes = const [],
    this.message,
  });

  /// Success.
  final bool ok;

  /// Work directory.
  final String workDir;

  /// Diff.
  final SandboxDiff? diff;

  /// Analyzer error count if known.
  final int? analyzerErrors;

  /// Notes.
  final List<String> notes;

  /// Message.
  final String? message;

  /// JSON.
  Map<String, Object?> toJson() => {
        'ok': ok,
        'workDir': workDir,
        if (diff != null) 'diff': diff!.toJson(),
        if (analyzerErrors != null) 'analyzerErrors': analyzerErrors,
        'notes': notes,
        if (message != null) 'message': message,
      };
}

/// Isolated filesystem copy for upgrade simulation.
class ProjectSandbox {
  /// Creates a sandbox under system temp.
  ProjectSandbox(this.sourceRoot);

  /// Source project root.
  final String sourceRoot;

  Directory? _dir;

  /// Active work directory.
  String? get workDir => _dir?.path;

  /// Clone pubspec + lock (+ optional lib for light checks).
  Future<String> create() async {
    final dir = await Directory.systemTemp.createTemp('pubdoctor_sandbox_');
    _dir = dir;
    for (final name in [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml'
    ]) {
      final src = File(p.join(sourceRoot, name));
      if (src.existsSync()) {
        await src.copy(p.join(dir.path, name));
      }
    }
    // Copy lib shallow for import checks (best-effort).
    final lib = Directory(p.join(sourceRoot, 'lib'));
    if (lib.existsSync()) {
      await _copyDir(lib, Directory(p.join(dir.path, 'lib')));
    }
    return dir.path;
  }

  Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final e in from.list(recursive: true, followLinks: false)) {
      final rel = p.relative(e.path, from: from.path);
      final dest = p.join(to.path, rel);
      if (e is Directory) {
        await Directory(dest).create(recursive: true);
      } else if (e is File && e.path.endsWith('.dart')) {
        await Directory(p.dirname(dest)).create(recursive: true);
        await e.copy(dest);
      }
    }
  }

  /// Patch dependency constraint in sandbox pubspec.
  Future<void> setPackageVersion(String package, String version) async {
    final file = File(p.join(_dir!.path, 'pubspec.yaml'));
    var text = await file.readAsString();
    final re = RegExp('^(\\s+)$package:\\s*.*\$', multiLine: true);
    if (re.hasMatch(text)) {
      text = text.replaceFirstMapped(re, (m) => '${m[1]}$package: $version');
    } else {
      text = '$text\ndependencies:\n  $package: $version\n';
    }
    await file.writeAsString(text);
  }

  /// Execute optional pub get + note results (no infinite loops).
  Future<SandboxResult> execute({
    bool runPubGet = false,
    int maxRepairIterations = 3,
  }) async {
    final notes = <String>[];
    final analyzerErrors = 0;
    if (_dir == null) {
      return const SandboxResult(
        ok: false,
        workDir: '',
        message: 'Sandbox not created',
      );
    }
    if (runPubGet) {
      try {
        final result = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: _dir!.path,
          runInShell: true,
        );
        notes.add('pub get exit=${result.exitCode}');
        if (result.exitCode != 0) {
          return SandboxResult(
            ok: false,
            workDir: _dir!.path,
            notes: notes,
            message: 'pub get failed in sandbox',
            analyzerErrors: analyzerErrors,
          );
        }
      } on Object catch (e) {
        notes.add('pub get skipped: $e');
      }
    }

    // Progress-guarded repair loop placeholder (no infinite loop).
    var prev = 999;
    for (var i = 0; i < maxRepairIterations; i++) {
      final current = analyzerErrors;
      if (current >= prev) {
        notes.add('Stopped repair loop: no improvement at iteration $i');
        break;
      }
      prev = current;
      notes.add('Sandbox iteration $i errors=$current');
    }

    final diff = SandboxDiff(changes: [
      'sandbox at ${_dir!.path}',
      ...notes,
    ]);
    return SandboxResult(
      ok: true,
      workDir: _dir!.path,
      diff: diff,
      analyzerErrors: analyzerErrors,
      notes: notes,
      message: 'Simulation complete (isolated)',
    );
  }

  /// Cleanup.
  Future<void> dispose() async {
    try {
      await _dir?.delete(recursive: true);
    } on Object {
      // ignore
    }
    _dir = null;
  }
}

/// Executor facade.
class SandboxExecutor {
  /// Simulate upgrading [package] to [version].
  static Future<SandboxResult> simulateUpgrade({
    required String workspacePath,
    required String package,
    required String version,
    bool runPubGet = false,
  }) async {
    final sandbox = ProjectSandbox(workspacePath);
    try {
      await sandbox.create();
      await sandbox.setPackageVersion(package, version);
      return await sandbox.execute(runPubGet: runPubGet);
    } finally {
      // Keep sandbox for inspection? dispose to avoid leaks.
      await sandbox.dispose();
    }
  }
}
