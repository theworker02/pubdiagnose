import '../models/diagnostics.dart';
import '../models/metadata.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';

/// Builds evidence-based recommendations from analysis results.
class RecommendationEngine {
  /// Creates a recommendation engine.
  RecommendationEngine(this.workspace);

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Recommendations from override analysis.
  List<Recommendation> fromOverrides(List<OverrideAnalysis> overrides) {
    return [
      for (final o in overrides)
        Recommendation(
          type: switch (o.classification) {
            OverrideClassification.possiblyUnnecessary =>
              RecommendationType.removeOverride,
            OverrideClassification.necessary => RecommendationType.keepOverride,
            OverrideClassification.unsafe => RecommendationType.keepOverride,
            OverrideClassification.unknown => RecommendationType.info,
          },
          severity: switch (o.classification) {
            OverrideClassification.unsafe => DiagnosticSeverity.warning,
            OverrideClassification.possiblyUnnecessary =>
              DiagnosticSeverity.info,
            _ => DiagnosticSeverity.info,
          },
          package: o.package,
          explanation: o.explanation,
          confidence: switch (o.classification) {
            OverrideClassification.necessary => RecommendationConfidence.high,
            OverrideClassification.possiblyUnnecessary =>
              RecommendationConfidence.medium,
            OverrideClassification.unsafe => RecommendationConfidence.medium,
            OverrideClassification.unknown => RecommendationConfidence.low,
          },
          changes: [
            if (o.classification == OverrideClassification.possiblyUnnecessary)
              ProposedChange(
                package: o.package,
                description:
                    'Remove dependency_overrides entry for ${o.package}',
                risk: ChangeRisk.unknownImpact,
              ),
          ],
          evidence: [
            if (o.declaredConstraint != null) o.declaredConstraint!,
            if (o.resolvedVersion != null) 'resolved ${o.resolvedVersion}',
          ],
        ),
    ];
  }

  /// Recommendations from outdated reports.
  List<Recommendation> fromOutdated(List<OutdatedPackage> outdated) {
    final result = <Recommendation>[];
    for (final o in outdated) {
      if (o.hasCompatibleUpgrade) {
        result.add(
          Recommendation(
            type: RecommendationType.upgradeDependency,
            severity: DiagnosticSeverity.info,
            package: o.package,
            explanation: '${o.package} can upgrade from ${o.current} to '
                '${o.latestCompatible} within current constraints. '
                'Semver does not guarantee behavior preservation.',
            confidence: RecommendationConfidence.high,
            changes: [
              ProposedChange(
                package: o.package,
                description: 'Upgrade to ${o.latestCompatible}',
                risk: ChangeRisk.safe,
                from: o.current.toString(),
                to: o.latestCompatible.toString(),
              ),
            ],
          ),
        );
      } else if (o.hasIncompatibleNewer) {
        final blocker = o.blockers.isEmpty ? null : o.blockers.first;
        result.add(
          Recommendation(
            type: RecommendationType.loosenConstraint,
            severity: DiagnosticSeverity.warning,
            package: o.package,
            explanation: blocker == null
                ? '${o.package} ${o.latestStable} is available but blocked by '
                    'constraints.'
                : '${o.package} ${o.latestStable} is blocked by '
                    '${blocker.blockedBy} (${blocker.constraint}).',
            confidence: RecommendationConfidence.medium,
            evidence: [for (final b in o.blockers) b.explanation],
            changes: [
              for (final b in o.blockers.take(3))
                ProposedChange(
                  package: b.blockedBy,
                  description:
                      'Adjust ${b.blockedBy} so ${o.package} ${o.latestStable} is allowed',
                  risk: ChangeRisk.potentiallyBreaking,
                ),
            ],
          ),
        );
      }
    }
    return result;
  }
}
