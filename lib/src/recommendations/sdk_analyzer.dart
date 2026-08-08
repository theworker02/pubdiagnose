import 'package:pub_semver/pub_semver.dart';

import '../metadata/package_repository.dart';
import '../models/diagnostics.dart';
import '../models/exceptions.dart';
import '../models/metadata.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';

/// Analyzes which dependencies block a target Dart or Flutter SDK.
class SdkAnalyzer {
  /// Creates an SDK analyzer.
  SdkAnalyzer({
    required this.workspace,
    required this.repository,
  });

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Package metadata source.
  final PackageRepository repository;

  /// Explains blockers for targeting Dart SDK [version].
  Future<SdkUpgradeReport> analyzeDart(String version) async {
    final target = _parseSdkVersion(version);
    return _analyze(
      kind: 'dart',
      target: target,
      readConstraint: (info) => info.sdkConstraint,
      environmentConstraint: workspace.pubspec.environment.sdk,
    );
  }

  /// Explains blockers for targeting Flutter SDK [version].
  ///
  /// Does not require the Flutter SDK to be installed; uses package metadata
  /// `environment.flutter` constraints when available.
  Future<SdkUpgradeReport> analyzeFlutter(String version) async {
    final target = _parseSdkVersion(version);
    return _analyze(
      kind: 'flutter',
      target: target,
      readConstraint: (info) => info.flutterConstraint,
      environmentConstraint: workspace.pubspec.environment.flutter,
    );
  }

  Future<SdkUpgradeReport> _analyze({
    required String kind,
    required Version target,
    required VersionConstraint? Function(PackageVersionInfo info)
        readConstraint,
    required VersionConstraint? environmentConstraint,
  }) async {
    final lockfile = workspace.lockfile;
    if (lockfile == null) {
      throw InvalidProjectException(
        'pubspec.lock is required for SDK analysis. Run `dart pub get`.',
        code: 'PD0005',
      );
    }

    final blockers = <SdkPackageBlocker>[];
    final recommendations = <Recommendation>[];

    if (environmentConstraint != null &&
        !environmentConstraint.allows(target)) {
      recommendations.add(
        Recommendation(
          type: RecommendationType.adjustSdk,
          severity: DiagnosticSeverity.warning,
          package: workspace.pubspec.name,
          explanation: 'Your pubspec environment.$kind constraint '
              '($environmentConstraint) does not allow $target.',
          confidence: RecommendationConfidence.high,
          changes: [
            ProposedChange(
              package: workspace.pubspec.name,
              description: 'Update environment.$kind to allow $target',
              risk: ChangeRisk.potentiallyBreaking,
              from: environmentConstraint.toString(),
              to: '^${target.major}.${target.minor}.0',
            ),
          ],
        ),
      );
    }

    for (final locked in lockfile.packages.values) {
      if (locked.source != 'hosted') continue;
      PackageMetadata meta;
      try {
        meta = await repository.getPackage(locked.name);
      } on PackageRepositoryException {
        continue;
      }

      final info = meta.versionInfo(locked.version);
      final constraint = info == null ? null : readConstraint(info);
      if (constraint == null) continue;
      if (constraint.allows(target)) continue;

      final path = workspace.graph.shortestPathTo(locked.name);
      blockers.add(
        SdkPackageBlocker(
          package: locked.name,
          version: locked.version,
          constraint: constraint,
          path: path?.display,
          explanation:
              '${locked.name} ${locked.version} requires $kind $constraint, '
              'which excludes $target.',
        ),
      );

      // Suggest newer package version that allows the SDK, if any.
      PackageVersionInfo? candidate;
      for (final v in meta.versions) {
        if (v.retracted) continue;
        if (v.version <= locked.version) continue;
        final c = readConstraint(v);
        if (c == null || c.allows(target)) {
          if (candidate == null || v.version < candidate.version) {
            candidate = v;
          }
        }
      }

      recommendations.add(
        Recommendation(
          type: RecommendationType.upgradeDependency,
          severity: DiagnosticSeverity.error,
          package: locked.name,
          explanation: candidate == null
              ? '${locked.name} ${locked.version} blocks $kind $target and no '
                  'newer published version clearly allows it.'
              : 'Upgrade ${locked.name} to ${candidate.version} (or newer) to '
                  'allow $kind $target. Behavior compatibility is not guaranteed.',
          confidence: candidate == null
              ? RecommendationConfidence.low
              : RecommendationConfidence.medium,
          evidence: [
            'Current: ${locked.name} ${locked.version} → $kind $constraint',
            if (path != null) 'Path: ${path.display}',
          ],
          changes: [
            if (candidate != null)
              ProposedChange(
                package: locked.name,
                description: 'Upgrade toward ${candidate.version}',
                risk: ChangeRisk.potentiallyBreaking,
                from: locked.version.toString(),
                to: candidate.version.toString(),
              ),
          ],
        ),
      );
    }

    blockers.sort((a, b) => a.package.compareTo(b.package));

    return SdkUpgradeReport(
      kind: kind,
      target: target,
      blockers: blockers,
      recommendations: recommendations,
      explanation: blockers.isEmpty
          ? 'No locked hosted packages declare an incompatible $kind '
              'constraint for $target.'
          : '${blockers.length} package(s) declare $kind constraints that '
              'exclude $target.',
    );
  }

  Version _parseSdkVersion(String raw) {
    final cleaned = raw.trim();
    try {
      return Version.parse(cleaned);
    } on FormatException {
      // Allow partial like "3.5" → 3.5.0
      final parts = cleaned.split('.');
      if (parts.length == 2) {
        return Version.parse('$cleaned.0');
      }
      throw InvalidProjectException(
        'Invalid SDK version "$raw". Expected a semver version like 3.5.0.',
        code: 'PD0006',
      );
    }
  }
}

/// A package whose SDK constraint blocks a target SDK.
class SdkPackageBlocker {
  /// Creates a blocker.
  const SdkPackageBlocker({
    required this.package,
    required this.version,
    required this.constraint,
    required this.explanation,
    this.path,
  });

  /// Package name.
  final String package;

  /// Locked version.
  final Version version;

  /// Blocking SDK constraint.
  final VersionConstraint constraint;

  /// Explanation.
  final String explanation;

  /// Dependency path display.
  final String? path;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'version': version.toString(),
        'constraint': constraint.toString(),
        'explanation': explanation,
        if (path != null) 'path': path,
      };
}

/// SDK upgrade analysis report.
class SdkUpgradeReport {
  /// Creates a report.
  const SdkUpgradeReport({
    required this.kind,
    required this.target,
    required this.blockers,
    required this.recommendations,
    required this.explanation,
  });

  /// `dart` or `flutter`.
  final String kind;

  /// Target SDK version.
  final Version target;

  /// Package blockers.
  final List<SdkPackageBlocker> blockers;

  /// Recommendations.
  final List<Recommendation> recommendations;

  /// Summary explanation.
  final String explanation;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'kind': kind,
        'target': target.toString(),
        'explanation': explanation,
        'blockers': blockers.map((b) => b.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
      };
}
