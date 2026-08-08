import 'package:pub_semver/pub_semver.dart';

import '../constraints/constraint_analyzer.dart';
import '../metadata/package_repository.dart';
import '../models/diagnostics.dart';
import '../models/exceptions.dart';
import '../models/metadata.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';

/// Explains outdated packages and upgrade blockers.
class UpgradeAnalyzer {
  /// Creates an upgrade analyzer.
  UpgradeAnalyzer({
    required this.workspace,
    required this.repository,
    ConstraintAnalyzer? constraintAnalyzer,
  }) : _constraints = constraintAnalyzer ?? ConstraintAnalyzer(workspace);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Package metadata source.
  final PackageRepository repository;

  final ConstraintAnalyzer _constraints;

  /// Reports outdated packages with explanations.
  Future<List<OutdatedPackage>> outdated({
    bool directOnly = false,
  }) async {
    final lockfile = workspace.lockfile;
    if (lockfile == null) {
      throw InvalidProjectException(
        'pubspec.lock is required for outdated analysis. Run `dart pub get`.',
        code: 'PD0005',
      );
    }

    final requirements = _constraints.collectRequirements();
    final packages = lockfile.packages.values.where((p) {
      if (p.source == 'sdk' || p.source == 'path') return false;
      if (directOnly) return p.isDirectMain || p.isDirectDev;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final results = <OutdatedPackage>[];
    for (final locked in packages) {
      PackageMetadata meta;
      try {
        meta = await repository.getPackage(locked.name);
      } on PackageRepositoryException {
        continue;
      }

      final reqs = requirements[locked.name] ?? const [];
      VersionConstraint combined = VersionConstraint.any;
      for (final r in reqs) {
        combined = combined.intersect(r.constraint);
      }
      final rootSpec = workspace.pubspec.dependency(locked.name);
      if (rootSpec != null) {
        combined = combined.intersect(rootSpec.constraint);
      }

      final latestCompatible = meta.latestCompatible(constraint: combined);
      final latest = meta.latest;
      final latestStable = meta.latestStable;

      final blockers = <UpgradeBlocker>[];
      final target = latestStable ?? latest;
      if (target != null && target > locked.version) {
        for (final r in reqs) {
          if (!r.constraint.allows(target)) {
            blockers.add(
              UpgradeBlocker(
                package: locked.name,
                blockedBy: r.requiredBy,
                constraint: r.constraint,
                desiredVersion: target,
                path: r.path.display,
                explanation:
                    '${r.requiredBy} requires ${locked.name} ${r.constraint}, '
                    'which excludes $target.',
              ),
            );
          }
        }
        if (rootSpec != null && !rootSpec.constraint.allows(target)) {
          blockers.add(
            UpgradeBlocker(
              package: locked.name,
              blockedBy: workspace.pubspec.name,
              constraint: rootSpec.constraint,
              desiredVersion: target,
              path: workspace.pubspec.name,
              explanation: 'Your pubspec constrains ${locked.name} to '
                  '${rootSpec.constraint}, which excludes $target.',
            ),
          );
        }
      }

      final explanation = _explain(
        current: locked.version,
        latestCompatible: latestCompatible,
        latestStable: latestStable,
        blockers: blockers,
      );

      final isInteresting =
          (latestCompatible != null && latestCompatible > locked.version) ||
              (latestStable != null && latestStable > locked.version) ||
              blockers.isNotEmpty;

      if (!isInteresting) continue;

      results.add(
        OutdatedPackage(
          package: locked.name,
          current: locked.version,
          declaredConstraint: rootSpec?.constraint,
          latestCompatible: latestCompatible,
          latest: latest,
          latestStable: latestStable,
          blockers: blockers,
          explanation: explanation,
        ),
      );
    }

    return results;
  }

  /// Explains what blocks unlocking [package] to [desired] (or latest).
  Future<UnlockReport> unlock(String package, {String? version}) async {
    final lockfile = workspace.lockfile;
    if (lockfile == null) {
      throw InvalidProjectException(
        'pubspec.lock is required for unlock analysis. Run `dart pub get`.',
        code: 'PD0005',
      );
    }

    final locked = lockfile[package];
    final meta = await repository.getPackage(package);

    Version desired;
    if (version != null) {
      desired = Version.parse(version);
    } else {
      desired = meta.latestStable ??
          meta.latest ??
          locked?.version ??
          Version.parse('0.0.0');
    }

    final requirements = _constraints.collectRequirements()[package] ?? [];
    final blockers = <UpgradeBlocker>[];
    final changes = <ProposedChange>[];
    final recommendations = <Recommendation>[];

    final rootSpec = workspace.pubspec.dependency(package);
    if (rootSpec != null && !rootSpec.constraint.allows(desired)) {
      blockers.add(
        UpgradeBlocker(
          package: package,
          blockedBy: workspace.pubspec.name,
          constraint: rootSpec.constraint,
          desiredVersion: desired,
          explanation:
              'Root constraint ${rootSpec.constraint} excludes $desired.',
        ),
      );
      final risk = _riskFor(locked?.version, desired);
      changes.add(
        ProposedChange(
          package: package,
          description: 'Loosen root constraint to allow $desired',
          risk: risk,
          from: rootSpec.constraint.toString(),
          to: _suggestConstraint(desired),
        ),
      );
    }

    for (final r in requirements) {
      if (r.requiredBy == workspace.pubspec.name) continue;
      if (!r.constraint.allows(desired)) {
        blockers.add(
          UpgradeBlocker(
            package: package,
            blockedBy: r.requiredBy,
            constraint: r.constraint,
            desiredVersion: desired,
            path: r.path.display,
            explanation: '${r.requiredBy} requires $package ${r.constraint}, '
                'blocking $desired.',
          ),
        );

        final parentLocked = lockfile[r.requiredBy];
        final risk = ChangeRisk.potentiallyBreaking;
        changes.add(
          ProposedChange(
            package: r.requiredBy,
            description:
                'Upgrade or replace ${r.requiredBy} so it allows $package $desired',
            risk: risk,
            from: parentLocked?.version.toString(),
          ),
        );

        recommendations.add(
          Recommendation(
            type: RecommendationType.upgradeDependency,
            severity: DiagnosticSeverity.warning,
            package: r.requiredBy,
            explanation:
                'To unlock $package $desired, ${r.requiredBy} must stop '
                'requiring ${r.constraint}. Prefer upgrading ${r.requiredBy} '
                'over adding an override.',
            confidence: RecommendationConfidence.medium,
            evidence: [
              '${r.path.display} → $package',
              'Constraint: ${r.constraint}',
            ],
            changes: [
              ProposedChange(
                package: r.requiredBy,
                description:
                    'Find a version of ${r.requiredBy} compatible with $package $desired',
                risk: ChangeRisk.unknownImpact,
              ),
            ],
          ),
        );
      }
    }

    if (blockers.isEmpty) {
      recommendations.add(
        Recommendation(
          type: RecommendationType.upgradeDependency,
          severity: DiagnosticSeverity.info,
          package: package,
          explanation: locked == null
              ? '$package $desired appears unconstrained by the current graph.'
              : '$package can move from ${locked.version} to $desired based on '
                  'known graph constraints. This does not guarantee pub will '
                  'resolve or that APIs stay compatible.',
          confidence: RecommendationConfidence.medium,
          changes: [
            if (rootSpec != null)
              ProposedChange(
                package: package,
                description: 'Allow $desired in pubspec.yaml',
                risk: _riskFor(locked?.version, desired),
                from: rootSpec.constraint.toString(),
                to: _suggestConstraint(desired),
              ),
          ],
        ),
      );
    } else {
      recommendations.insert(
        0,
        Recommendation(
          type: RecommendationType.loosenConstraint,
          severity: DiagnosticSeverity.error,
          package: package,
          explanation: 'Unlocking $package to $desired requires changes in '
              '${blockers.map((b) => b.blockedBy).toSet().join(', ')}.',
          confidence: RecommendationConfidence.high,
          evidence: [for (final b in blockers) b.explanation],
          changes: changes,
        ),
      );
    }

    return UnlockReport(
      package: package,
      current: locked?.version,
      desired: desired,
      blockers: blockers,
      recommendations: recommendations,
    );
  }

  String _explain({
    required Version current,
    required Version? latestCompatible,
    required Version? latestStable,
    required List<UpgradeBlocker> blockers,
  }) {
    if (latestCompatible != null && latestCompatible > current) {
      return 'Compatible upgrade available: $current → $latestCompatible.';
    }
    if (latestStable != null && latestStable > current) {
      if (blockers.isEmpty) {
        return 'Newer stable $latestStable exists; no single graph constraint '
            'clearly blocks it (resolution may still fail).';
      }
      final primary = blockers.first;
      return 'Blocked from $latestStable: ${primary.blockedBy} requires '
          '${primary.constraint}.';
    }
    return 'No newer stable version found.';
  }

  ChangeRisk _riskFor(Version? from, Version to) {
    if (from == null) return ChangeRisk.unknownImpact;
    if (to.major > from.major) return ChangeRisk.potentiallyBreaking;
    if (from.major == 0 && to.minor > from.minor) {
      return ChangeRisk.potentiallyBreaking;
    }
    return ChangeRisk.safe;
  }

  String _suggestConstraint(Version version) {
    if (version.major == 0) {
      return '^${version.major}.${version.minor}.${version.patch}';
    }
    return '^${version.major}.${version.minor}.${version.patch}';
  }
}

/// Result of an unlock analysis.
class UnlockReport {
  /// Creates an unlock report.
  const UnlockReport({
    required this.package,
    required this.desired,
    required this.blockers,
    required this.recommendations,
    this.current,
  });

  /// Package name.
  final String package;

  /// Current resolved version.
  final Version? current;

  /// Desired version.
  final Version desired;

  /// Blockers.
  final List<UpgradeBlocker> blockers;

  /// Recommendations.
  final List<Recommendation> recommendations;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        if (current != null) 'current': current.toString(),
        'desired': desired.toString(),
        'blockers': blockers.map((b) => b.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
      };
}
