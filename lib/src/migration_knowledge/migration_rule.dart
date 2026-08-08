import 'package:pub_semver/pub_semver.dart';

/// Provenance of a migration rule.
enum MigrationProvenance {
  /// First-party PubDoctor rules.
  pubdoctor,

  /// Package-maintainer supplied metadata.
  packageMaintainer,

  /// Official Dart analyzer fix patterns.
  analyzerFix,

  /// Local project migration pack.
  localPack,
}

/// Evidence / citation for a migration rule.
class MigrationEvidence {
  /// Creates evidence.
  const MigrationEvidence({
    required this.summary,
    this.url,
    this.changelogRef,
  });

  /// Short summary.
  final String summary;

  /// Optional URL.
  final String? url;

  /// Changelog reference.
  final String? changelogRef;

  /// JSON.
  Map<String, Object?> toJson() => {
        'summary': summary,
        if (url != null) 'url': url,
        if (changelogRef != null) 'changelogRef': changelogRef,
      };
}

/// A single API change within a package migration.
class ApiChange {
  /// Creates an API change.
  const ApiChange({
    required this.fromSymbol,
    required this.toSymbol,
    this.kind = 'rename',
    this.notes,
    this.automated = false,
  });

  /// Old symbol / pattern.
  final String fromSymbol;

  /// New symbol / pattern.
  final String toSymbol;

  /// Kind: rename | signature | removal | behavior.
  final String kind;

  /// Notes.
  final String? notes;

  /// Whether deterministic automated repair exists.
  final bool automated;

  /// JSON.
  Map<String, Object?> toJson() => {
        'fromSymbol': fromSymbol,
        'toSymbol': toSymbol,
        'kind': kind,
        if (notes != null) 'notes': notes,
        'automated': automated,
      };
}

/// Version-scoped migration rule.
class MigrationRule {
  /// Creates a rule.
  const MigrationRule({
    required this.id,
    required this.package,
    required this.fromConstraint,
    required this.toConstraint,
    required this.provenance,
    this.apiChanges = const [],
    this.evidence = const [],
    this.risk = 'moderate',
    this.verification = const [],
    this.unsupportedBehavioral = const [],
  });

  /// Rule id.
  final String id;

  /// Package name (`dart` / `flutter` for SDK).
  final String package;

  /// Source version constraint.
  final String fromConstraint;

  /// Target version constraint.
  final String toConstraint;

  /// Provenance.
  final MigrationProvenance provenance;

  /// API changes.
  final List<ApiChange> apiChanges;

  /// Evidence.
  final List<MigrationEvidence> evidence;

  /// Risk classification.
  final String risk;

  /// Verification requirements.
  final List<String> verification;

  /// Unsupported behavioral changes.
  final List<String> unsupportedBehavioral;

  /// Whether [from]→[to] matches this rule's version window.
  bool matches(Version from, Version to) {
    try {
      final fromC = VersionConstraint.parse(fromConstraint);
      final toC = VersionConstraint.parse(toConstraint);
      return fromC.allows(from) && toC.allows(to);
    } on Object {
      return false;
    }
  }

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'package': package,
        'fromConstraint': fromConstraint,
        'toConstraint': toConstraint,
        'provenance': provenance.name,
        'apiChanges': [for (final c in apiChanges) c.toJson()],
        'evidence': [for (final e in evidence) e.toJson()],
        'risk': risk,
        'verification': verification,
        'unsupportedBehavioral': unsupportedBehavioral,
      };
}

/// Package-level migration description.
class PackageMigration {
  /// Creates a package migration.
  const PackageMigration({
    required this.package,
    required this.fromVersion,
    required this.toVersion,
    required this.rules,
  });

  /// Package.
  final String package;

  /// From.
  final String fromVersion;

  /// To.
  final String toVersion;

  /// Matching rules.
  final List<MigrationRule> rules;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'fromVersion': fromVersion,
        'toVersion': toVersion,
        'rules': [for (final r in rules) r.toJson()],
      };
}

/// SDK migration description.
class SdkMigration {
  /// Creates an SDK migration.
  const SdkMigration({
    required this.sdk,
    required this.fromVersion,
    required this.toVersion,
    required this.rules,
  });

  /// dart | flutter.
  final String sdk;

  /// From.
  final String fromVersion;

  /// To.
  final String toVersion;

  /// Rules.
  final List<MigrationRule> rules;

  /// JSON.
  Map<String, Object?> toJson() => {
        'sdk': sdk,
        'fromVersion': fromVersion,
        'toVersion': toVersion,
        'rules': [for (final r in rules) r.toJson()],
      };
}
