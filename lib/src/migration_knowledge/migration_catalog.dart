import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';

import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import 'migration_rule.dart';

/// Catalog of versioned migration rules with provenance.
class MigrationCatalog {
  /// Creates a catalog.
  MigrationCatalog({List<MigrationRule>? rules})
      : _rules = [...?rules, ...builtin];

  final List<MigrationRule> _rules;

  /// All rules.
  List<MigrationRule> get rules => List.unmodifiable(_rules);

  /// Built-in first-party rules.
  static const List<MigrationRule> builtin = [
    MigrationRule(
      id: 'http-1-to-2-client',
      package: 'http',
      fromConstraint: '>=0.13.0 <1.0.0',
      toConstraint: '>=1.0.0 <2.0.0',
      provenance: MigrationProvenance.pubdoctor,
      risk: 'low',
      apiChanges: [
        ApiChange(
          fromSymbol: 'Client()',
          toSymbol: 'Client()',
          kind: 'behavior',
          notes: 'Default Client construction remains; review custom adapters.',
          automated: false,
        ),
      ],
      evidence: [
        MigrationEvidence(
          summary: 'http 1.0 major release notes',
          changelogRef: 'http@1.0.0',
        ),
      ],
      verification: ['dart analyze', 'pubdoctor check'],
    ),
    MigrationRule(
      id: 'collection-1-to-2',
      package: 'collection',
      fromConstraint: '>=1.15.0 <1.18.0',
      toConstraint: '>=1.18.0 <2.0.0',
      provenance: MigrationProvenance.pubdoctor,
      risk: 'low',
      apiChanges: [
        ApiChange(
          fromSymbol: 'UnmodifiableListView',
          toSymbol: 'UnmodifiableListView',
          kind: 'behavior',
          notes: 'Most APIs stable; re-run analyzer for deprecated members.',
          automated: false,
        ),
      ],
      evidence: [
        MigrationEvidence(summary: 'collection minor compatibility window'),
      ],
      verification: ['dart analyze'],
    ),
    MigrationRule(
      id: 'dart-sdk-3-5-to-3-6',
      package: 'dart',
      fromConstraint: '>=3.5.0 <3.6.0',
      toConstraint: '>=3.6.0 <3.7.0',
      provenance: MigrationProvenance.pubdoctor,
      risk: 'moderate',
      apiChanges: [
        ApiChange(
          fromSymbol: 'language-3.5',
          toSymbol: 'language-3.6',
          kind: 'behavior',
          notes: 'Update SDK constraint; review analyzer new lints.',
          automated: false,
        ),
      ],
      evidence: [
        MigrationEvidence(summary: 'Dart SDK release notes'),
      ],
      verification: ['dart analyze', 'pubdoctor sdk dart'],
      unsupportedBehavioral: [
        'Runtime behavior changes outside language specification are not auto-migrated.',
      ],
    ),
  ];

  /// Find rules matching package and versions.
  List<MigrationRule> find({
    required String package,
    required Version from,
    required Version to,
  }) {
    return [
      for (final r in _rules)
        if (r.package == package && r.matches(from, to)) r,
    ];
  }

  /// Explain a package migration.
  PackageMigration explainPackage({
    required String package,
    required String from,
    required String to,
  }) {
    final fromV = Version.parse(_normalizeVersion(from));
    final toV = Version.parse(_normalizeVersion(to));
    return PackageMigration(
      package: package,
      fromVersion: fromV.toString(),
      toVersion: toV.toString(),
      rules: find(package: package, from: fromV, to: toV),
    );
  }

  /// Load optional migration packs from [packsRoot].
  void loadPacks(String packsRoot, FilesystemAdapter fs, PathAdapter paths) {
    for (final area in ['dart_sdk', 'flutter', 'packages']) {
      final dir = paths.join(packsRoot, area);
      if (!fs.directoryExists(dir)) continue;
      for (final entity in fs.listDirectory(dir)) {
        final name = paths.basename(entity.path);
        if (!name.endsWith('.json')) continue;
        final path = entity.path;
        try {
          final text = fs.readText(path);
          if (text == null) continue;
          final raw = jsonDecode(text);
          if (raw is! Map) continue;
          final map = Map<String, Object?>.from(raw.cast<String, Object?>());
          _rules.add(_ruleFromPack(map, area));
        } on Object {
          // Skip malformed packs rather than failing the catalog.
        }
      }
    }
  }

  static MigrationRule _ruleFromPack(Map<String, Object?> map, String area) {
    return MigrationRule(
      id: map['id']?.toString() ?? 'pack-${map.hashCode}',
      package: map['package']?.toString() ?? area,
      fromConstraint: map['fromConstraint']?.toString() ?? 'any',
      toConstraint: map['toConstraint']?.toString() ?? 'any',
      provenance: MigrationProvenance.localPack,
      risk: map['risk']?.toString() ?? 'moderate',
      apiChanges: [
        for (final c in (map['transformations'] as List?) ??
            (map['apiChanges'] as List?) ??
            const [])
          ApiChange(
            fromSymbol: (c as Map)['from']?.toString() ??
                c['fromSymbol']?.toString() ??
                '',
            toSymbol: c['to']?.toString() ?? c['toSymbol']?.toString() ?? '',
            kind: c['kind']?.toString() ?? 'rename',
            notes: c['notes']?.toString(),
            automated: c['automated'] == true,
          ),
      ],
      verification: [
        for (final v in (map['verification'] as List?) ?? const [])
          v.toString(),
      ],
      evidence: [
        MigrationEvidence(
          summary:
              map['evidence']?.toString() ?? 'local migration pack ($area)',
        ),
      ],
    );
  }

  static String _normalizeVersion(String raw) {
    final t = raw.trim();
    if (RegExp(r'^\d+$').hasMatch(t)) return '$t.0.0';
    if (RegExp(r'^\d+\.\d+$').hasMatch(t)) return '$t.0';
    return t;
  }
}

/// Tracks which rule caused each edit (provenance ledger).
class MigrationProvenanceLedger {
  final List<Map<String, Object?>> _edits = [];

  /// Record an edit caused by [ruleId].
  void record({
    required String ruleId,
    required String file,
    required String description,
    required MigrationProvenance provenance,
  }) {
    _edits.add({
      'ruleId': ruleId,
      'file': file,
      'description': description,
      'provenance': provenance.name,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// All recorded edits.
  List<Map<String, Object?>> get edits => List.unmodifiable(_edits);

  /// JSON.
  Map<String, Object?> toJson() => {'edits': edits};
}
