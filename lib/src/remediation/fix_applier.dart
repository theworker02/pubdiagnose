import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/exceptions.dart';
import '../workspace/workspace_loader.dart';
import 'fix_plan.dart';
import 'fix_planner.dart';

/// Applies [FixPlan] changes to pubspec.yaml transactionally.
class FixApplier {
  /// Creates an applier.
  FixApplier(this.workspace);

  /// Workspace.
  final PubWorkspace workspace;

  /// Propose only (default).
  FixPlan propose({
    String? code,
    String? package,
    bool safeOnly = false,
  }) {
    return FixPlanner(workspace).plan(
      code: code,
      package: package,
      safeOnly: safeOnly,
    );
  }

  /// Apply [plan] to pubspec.yaml with backup/rollback.
  Future<FixApplyResult> apply(
    FixPlan plan, {
    bool dryRun = false,
  }) async {
    if (plan.isEmpty) {
      return FixApplyResult(
        applied: false,
        plan: plan,
        message: 'No changes to apply.',
      );
    }

    final path = workspace.pubspecPath;
    final file = File(path);
    if (!file.existsSync()) {
      throw MissingPubspecException(workspace.root.path);
    }

    final original = file.readAsStringSync();
    String next;
    try {
      next = _mutate(original, plan.changes);
      // Validate YAML parses.
      final parsed = loadYaml(next);
      if (parsed is! YamlMap) {
        throw const FormatException('Mutated pubspec.yaml root is not a map.');
      }
      if (parsed['name'] == null) {
        throw const FormatException('Mutated pubspec.yaml missing name.');
      }
    } on Object catch (e) {
      return FixApplyResult(
        applied: false,
        plan: plan,
        message: 'Refusing to write invalid YAML: $e',
      );
    }

    if (dryRun) {
      return FixApplyResult(
        applied: false,
        plan: plan,
        message: 'Dry run — no files written.',
        wrotePath: path,
      );
    }

    final backupPath = p.join(workspace.root.path, '.pubdoctor_pubspec.bak');
    final backup = File(backupPath);
    try {
      backup.writeAsStringSync(original);
      file.writeAsStringSync(next);

      // Re-parse with PubDoctor loader semantics via YAML already validated.
      // If the new content cannot be read as UTF-8 etc., rollback.
      final verify = file.readAsStringSync();
      loadYaml(verify);

      if (backup.existsSync()) {
        backup.deleteSync();
      }
      return FixApplyResult(
        applied: true,
        plan: plan,
        message: 'Applied ${plan.changes.length} change(s) to $path. '
            'Run `dart pub get` and re-check.',
        wrotePath: path,
      );
    } on Object catch (e) {
      // Rollback.
      try {
        file.writeAsStringSync(original);
      } on Object {
        // ignore
      }
      return FixApplyResult(
        applied: false,
        rolledBack: true,
        plan: plan,
        message: 'Apply failed; rolled back. Error: $e',
        wrotePath: path,
      );
    }
  }

  String _mutate(String source, List<FixChange> changes) {
    var text = source;
    for (final change in changes) {
      switch (change.kind) {
        case FixChangeKind.removeOverride:
          text = _removeMapKey(text, 'dependency_overrides', change.package);
        case FixChangeKind.removeDependency:
          final section = change.section ?? 'dependencies';
          text = _removeMapKey(text, section, change.package);
        case FixChangeKind.addDependency:
          final section = change.section ?? 'dependencies';
          text = _addMapKey(
            text,
            section,
            change.package,
            change.to ?? 'any',
          );
        case FixChangeKind.moveDependency:
          // Not used by default planner yet.
          break;
        case FixChangeKind.adjustConstraint:
          final section = change.section ?? 'dependencies';
          if (change.to != null) {
            text = _setMapKey(text, section, change.package, change.to!);
          }
      }
    }
    return text;
  }

  /// Removes `key:` entry under [section] while preserving surrounding text.
  String _removeMapKey(String source, String section, String key) {
    final sectionPattern = RegExp(
      '^$section:\\s*\\n',
      multiLine: true,
    );
    final sectionMatch = sectionPattern.firstMatch(source);
    if (sectionMatch == null) return source;

    final start = sectionMatch.end;
    final nextSection = RegExp(r'^[a-zA-Z_][\w-]*:\s*$', multiLine: true);
    var end = source.length;
    for (final m in nextSection.allMatches(source, start)) {
      end = m.start;
      break;
    }

    final block = source.substring(start, end);
    final keyPattern = RegExp(
      '^  ${RegExp.escape(key)}:.*\\n(?:^    .*\\n)*',
      multiLine: true,
    );
    final newBlock = block.replaceFirst(keyPattern, '');
    if (newBlock == block) {
      // Try single-line without requiring trailing newline variants.
      final alt = RegExp(
        '^  ${RegExp.escape(key)}:.*(?:\\n|\$)',
        multiLine: true,
      );
      final replaced = block.replaceFirst(alt, '');
      return source.substring(0, start) + replaced + source.substring(end);
    }

    // If section becomes empty (only whitespace), drop the section header.
    if (newBlock.trim().isEmpty) {
      return source.substring(0, sectionMatch.start) + source.substring(end);
    }
    return source.substring(0, start) + newBlock + source.substring(end);
  }

  String _addMapKey(
    String source,
    String section,
    String key,
    String value,
  ) {
    final sectionPattern = RegExp(
      '^$section:\\s*\\n',
      multiLine: true,
    );
    final sectionMatch = sectionPattern.firstMatch(source);
    final entry = '  $key: $value\n';
    if (sectionMatch == null) {
      final suffix = source.endsWith('\n') ? '' : '\n';
      return '$source$suffix$section:\n$entry';
    }
    // Avoid duplicate.
    final exists = RegExp(
      '^  ${RegExp.escape(key)}:',
      multiLine: true,
    ).hasMatch(source);
    if (exists) return source;
    final insertAt = sectionMatch.end;
    return source.substring(0, insertAt) + entry + source.substring(insertAt);
  }

  String _setMapKey(
    String source,
    String section,
    String key,
    String value,
  ) {
    final pattern = RegExp(
      '(^$section:\\s*\\n(?:^(?:  |#if).*\\n)*?^  ${RegExp.escape(key)}:)(.*)\$',
      multiLine: true,
    );
    if (pattern.hasMatch(source)) {
      return source.replaceFirstMapped(pattern, (m) => '${m[1]} $value');
    }
    return _addMapKey(source, section, key, value);
  }
}
