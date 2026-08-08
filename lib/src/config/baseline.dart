import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/diagnostics.dart';

/// A saved baseline of known diagnostics for CI.
class Baseline {
  /// Creates a baseline.
  const Baseline({
    required this.entries,
    this.createdAt,
    this.project,
  });

  /// Fingerprint entries (`code|package|message`).
  final Set<String> entries;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Project name.
  final String? project;

  /// Empty baseline.
  static const empty = Baseline(entries: {});

  /// Fingerprint for a diagnostic.
  static String fingerprint(Diagnostic d) =>
      '${d.code}|${d.package ?? ''}|${d.message}';

  /// Diagnostics not present in this baseline.
  List<Diagnostic> newViolations(List<Diagnostic> diagnostics) {
    return [
      for (final d in diagnostics)
        if (!entries.contains(fingerprint(d))) d,
    ];
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
        'version': 1,
        if (project != null) 'project': project,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'entries': entries.toList()..sort(),
      };

  /// Parse from JSON map.
  factory Baseline.fromJson(Map<String, Object?> json) {
    final raw = json['entries'];
    final entries = <String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item != null) entries.add(item.toString());
      }
    }
    DateTime? created;
    final createdRaw = json['createdAt']?.toString();
    if (createdRaw != null) created = DateTime.tryParse(createdRaw);
    return Baseline(
      entries: entries,
      createdAt: created,
      project: json['project']?.toString(),
    );
  }
}

/// Reads/writes `.pubdoctor_baseline.json`.
class BaselineStore {
  /// Creates a store for [projectDir].
  BaselineStore(this.projectDir, {String? fileName})
      : filePath = p.join(
          projectDir,
          fileName ?? '.pubdoctor_baseline.json',
        );

  /// Project directory.
  final String projectDir;

  /// Baseline file path.
  final String filePath;

  /// Load baseline or empty.
  Baseline load() {
    final file = File(filePath);
    if (!file.existsSync()) return Baseline.empty;
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) return Baseline.empty;
    return Baseline.fromJson(Map<String, Object?>.from(json));
  }

  /// Create/replace baseline from diagnostics.
  Baseline create(List<Diagnostic> diagnostics, {String? project}) {
    final baseline = Baseline(
      entries: {for (final d in diagnostics) Baseline.fingerprint(d)},
      createdAt: DateTime.now().toUtc(),
      project: project,
    );
    File(filePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(baseline.toJson()),
    );
    return baseline;
  }

  /// Update baseline by union with new diagnostics.
  Baseline update(List<Diagnostic> diagnostics, {String? project}) {
    final current = load();
    final merged = {
      ...current.entries,
      for (final d in diagnostics) Baseline.fingerprint(d),
    };
    final baseline = Baseline(
      entries: merged,
      createdAt: DateTime.now().toUtc(),
      project: project ?? current.project,
    );
    File(filePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(baseline.toJson()),
    );
    return baseline;
  }

  /// Delete baseline file.
  bool clean() {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// Inspect summary.
  Map<String, Object?> inspect() {
    final baseline = load();
    final file = File(filePath);
    return {
      'path': filePath,
      'exists': file.existsSync(),
      'entryCount': baseline.entries.length,
      if (baseline.project != null) 'project': baseline.project,
      if (baseline.createdAt != null)
        'createdAt': baseline.createdAt!.toIso8601String(),
    };
  }
}
