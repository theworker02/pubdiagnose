import '../policy/policy_rule.dart';

/// Feature maturity levels for the public surface.
enum FeatureMaturity {
  /// Covered by SemVer stable guarantees.
  stable,

  /// May change in minor releases; documented as experimental.
  experimental,

  /// Scheduled for removal; prefer replacements.
  deprecated,

  /// Not part of the public API contract.
  internal,
}

/// Maturity metadata for a feature / command.
class FeatureMaturityInfo {
  /// Creates maturity info.
  const FeatureMaturityInfo({
    required this.id,
    required this.maturity,
    required this.summary,
    this.since,
    this.replaceWith,
  });

  /// Feature / command id.
  final String id;

  /// Maturity.
  final FeatureMaturity maturity;

  /// Short summary.
  final String summary;

  /// Version introduced when known.
  final String? since;

  /// Replacement when deprecated.
  final String? replaceWith;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'id': id,
        'maturity': maturity.name,
        'summary': summary,
        if (since != null) 'since': since,
        if (replaceWith != null) 'replaceWith': replaceWith,
      };
}

/// Catalog of feature maturity for help/docs/inspect.
abstract final class FeatureMaturityCatalog {
  /// All known entries.
  static const List<FeatureMaturityInfo> all = [
    FeatureMaturityInfo(
      id: 'check',
      maturity: FeatureMaturity.stable,
      summary: 'Unified health report',
      since: '1.0.0',
    ),
    FeatureMaturityInfo(
      id: 'why',
      maturity: FeatureMaturity.stable,
      summary: 'Explain why a package is installed',
      since: '1.0.0',
    ),
    FeatureMaturityInfo(
      id: 'explain',
      maturity: FeatureMaturity.stable,
      summary: 'Explain diagnostic codes or packages',
      since: '1.0.0',
    ),
    FeatureMaturityInfo(
      id: 'risk',
      maturity: FeatureMaturity.stable,
      summary: 'Evidence-driven dependency risk intelligence',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'migrate',
      maturity: FeatureMaturity.stable,
      summary: 'Ordered upgrade / SDK migration planning',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'policy',
      maturity: FeatureMaturity.stable,
      summary: 'Workspace governance policies',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'impact',
      maturity: FeatureMaturity.stable,
      summary: 'Change impact / reverse-dependency analysis',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'snapshot',
      maturity: FeatureMaturity.stable,
      summary: 'Persistent project intelligence snapshots',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'drift',
      maturity: FeatureMaturity.stable,
      summary: 'Compare current state to snapshots',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'debug',
      maturity: FeatureMaturity.experimental,
      summary: 'Profiling and incremental invalidation diagnostics',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'health',
      maturity: FeatureMaturity.stable,
      summary: 'Internal PubDoctor health',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'heal',
      maturity: FeatureMaturity.stable,
      summary: 'T0 internal self-healing',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'source',
      maturity: FeatureMaturity.experimental,
      summary: 'Lightweight source diagnostics',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'repair',
      maturity: FeatureMaturity.experimental,
      summary: 'Transactional deterministic repair',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'upgrade',
      maturity: FeatureMaturity.experimental,
      summary: 'Sandbox upgrade simulation',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'environment',
      maturity: FeatureMaturity.stable,
      summary: 'Runtime environment doctor',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'watch',
      maturity: FeatureMaturity.experimental,
      summary: 'Continuous integrity watch',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'audit',
      maturity: FeatureMaturity.stable,
      summary: 'Repair / internal audits',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'distributed',
      maturity: FeatureMaturity.experimental,
      summary: 'Distributed local/remote analysis workers',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'reproduce',
      maturity: FeatureMaturity.experimental,
      summary: 'Environment reproducibility manifests',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'migration',
      maturity: FeatureMaturity.experimental,
      summary: 'Semantic migration knowledge explain',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'ecosystem',
      maturity: FeatureMaturity.experimental,
      summary: 'Pub ecosystem observatory',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'security',
      maturity: FeatureMaturity.experimental,
      summary: 'Supply-chain integrity checks',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'maintain',
      maturity: FeatureMaturity.experimental,
      summary: 'Bounded maintenance controller',
      since: '2.0.0-rc.1',
    ),
    FeatureMaturityInfo(
      id: 'plugins',
      maturity: FeatureMaturity.experimental,
      summary: 'Controlled plugin surface for analyzer modules',
      since: '1.1.0',
    ),
  ];

  /// Lookup by id.
  static FeatureMaturityInfo? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// JSON list.
  static List<Map<String, Object?>> toJsonList() =>
      [for (final e in all) e.toJson()];
}

/// Re-export policy rule kind for docs cross-links.
typedef PolicyKinds = PolicyRuleKind;
