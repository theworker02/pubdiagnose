import 'environment_snapshot.dart';

/// A single environment difference.
class EnvironmentDiffEntry {
  /// Creates an entry.
  const EnvironmentDiffEntry({
    required this.path,
    required this.left,
    required this.right,
    this.impact,
  });

  /// Dot path (e.g. sdk.dartVersion).
  final String path;

  /// Left value.
  final Object? left;

  /// Right value.
  final Object? right;

  /// Optional impact note.
  final String? impact;

  /// JSON.
  Map<String, Object?> toJson() => {
        'path': path,
        'left': left,
        'right': right,
        if (impact != null) 'impact': impact,
      };
}

/// Diff between two environment snapshots.
class EnvironmentDiff {
  /// Creates a diff.
  const EnvironmentDiff({
    required this.entries,
    this.summary,
  });

  /// Entries.
  final List<EnvironmentDiffEntry> entries;

  /// Summary.
  final String? summary;

  /// Whether any differences exist.
  bool get isEmpty => entries.isEmpty;

  /// JSON.
  Map<String, Object?> toJson() => {
        'summary': summary,
        'count': entries.length,
        'entries': [for (final e in entries) e.toJson()],
      };

  /// Compare [a] vs [b].
  static EnvironmentDiff compare(
    EnvironmentSnapshot a,
    EnvironmentSnapshot b,
  ) {
    final entries = <EnvironmentDiffEntry>[];

    void add(String path, Object? left, Object? right, [String? impact]) {
      if (left?.toString() == right?.toString()) return;
      entries.add(
        EnvironmentDiffEntry(
          path: path,
          left: left,
          right: right,
          impact: impact,
        ),
      );
    }

    add(
      'sdk.dartVersion',
      a.sdk.dartVersion,
      b.sdk.dartVersion,
      'Package resolution and SDK constraints may diverge.',
    );
    add('sdk.flutterVersion', a.sdk.flutterVersion, b.sdk.flutterVersion);
    add('platform.os', a.platform.os, b.platform.os);
    add(
      'platform.architecture',
      a.platform.architecture,
      b.platform.architecture,
    );
    add('platform.isCi', a.platform.isCi, b.platform.isCi);
    add('platform.locale', a.platform.locale, b.platform.locale);
    add(
      'cache.lockfilePackageCount',
      a.cache.lockfilePackageCount,
      b.cache.lockfilePackageCount,
      'Lockfile resolution differs; pub get may change the graph.',
    );
    add(
      'lockfileHash',
      a.lockfileHash,
      b.lockfileHash,
      'Resolved package set differs between environments.',
    );
    add('tools.gitAvailable', a.tools.gitAvailable, b.tools.gitAvailable);
    add(
      'tools.flutterAvailable',
      a.tools.flutterAvailable,
      b.tools.flutterAvailable,
    );

    final aCaps = a.capabilities.toSet();
    final bCaps = b.capabilities.toSet();
    if (aCaps.difference(bCaps).isNotEmpty ||
        bCaps.difference(aCaps).isNotEmpty) {
      add(
        'capabilities',
        a.capabilities.join(','),
        b.capabilities.join(','),
        'PubDoctor capability level differs.',
      );
    }

    return EnvironmentDiff(
      entries: entries,
      summary: entries.isEmpty
          ? 'Environments match on compared axes.'
          : '${entries.length} environment difference(s).',
    );
  }
}

/// Reproducibility check report.
class ReproduceReport {
  /// Creates a report.
  const ReproduceReport({
    required this.ok,
    required this.findings,
    this.manifest,
  });

  /// Whether environment looks reproducible enough for local resolution.
  final bool ok;

  /// Findings.
  final List<String> findings;

  /// Optional export manifest.
  final Map<String, Object?>? manifest;

  /// JSON.
  Map<String, Object?> toJson() => {
        'ok': ok,
        'findings': findings,
        if (manifest != null) 'manifest': manifest,
      };

  /// Analyze [snapshot] for reproducibility risks.
  static ReproduceReport check(EnvironmentSnapshot snapshot) {
    final findings = <String>[];
    if (snapshot.sdk.dartVersion == null) {
      findings
          .add('Dart version unknown — resolution may not be reproducible.');
    }
    if (snapshot.lockfileHash == null) {
      findings.add('No lockfile hash — run pub get to pin the graph.');
    }
    if (snapshot.platform.isCi) {
      findings.add(
        'CI profile detected — PATH and cache layout often differ from desktops.',
      );
    }
    if (!snapshot.cache.pubCachePresent) {
      findings
          .add('Pub cache presence unclear — first-time resolves may drift.');
    }
    return ReproduceReport(
      ok: findings.isEmpty,
      findings: findings,
    );
  }

  /// Export a portable reproduction manifest (sanitized).
  static Map<String, Object?> exportManifest(EnvironmentSnapshot snapshot) {
    return EnvironmentSnapshotEngine.sanitize({
      'kind': 'pubdoctor.reproduce.manifest',
      'schemaVersion': 1,
      'sdk': snapshot.sdk.toJson(),
      'platform': {
        'os': snapshot.platform.os,
        'architecture': snapshot.platform.architecture,
        'isCi': snapshot.platform.isCi,
      },
      'lockfileHash': snapshot.lockfileHash,
      'lockfilePackageCount': snapshot.cache.lockfilePackageCount,
      'projectName': snapshot.projectName,
      'capabilities': snapshot.capabilities,
    });
  }
}
