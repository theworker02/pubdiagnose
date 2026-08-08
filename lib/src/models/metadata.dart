import 'package:pub_semver/pub_semver.dart';

/// Metadata for a single published version.
class PackageVersionInfo {
  /// Creates version info.
  const PackageVersionInfo({
    required this.version,
    this.published,
    this.retracted = false,
    this.sdkConstraint,
    this.flutterConstraint,
    this.dependencies = const {},
    this.devDependencies = const {},
  });

  /// Version.
  final Version version;

  /// Publish timestamp when known.
  final DateTime? published;

  /// Whether retracted.
  final bool retracted;

  /// Dart SDK constraint from that version's pubspec.
  final VersionConstraint? sdkConstraint;

  /// Flutter SDK constraint from that version's pubspec.
  final VersionConstraint? flutterConstraint;

  /// Dependencies of this version.
  final Map<String, VersionConstraint> dependencies;

  /// Dev dependencies of this version.
  final Map<String, VersionConstraint> devDependencies;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'version': version.toString(),
        if (published != null) 'published': published!.toIso8601String(),
        'retracted': retracted,
        if (sdkConstraint != null) 'sdkConstraint': sdkConstraint.toString(),
        if (flutterConstraint != null)
          'flutterConstraint': flutterConstraint.toString(),
      };
}

/// Package metadata from a repository (e.g. pub.dev).
class PackageMetadata {
  /// Creates package metadata.
  const PackageMetadata({
    required this.name,
    required this.versions,
    this.latest,
    this.latestStable,
    this.description,
    this.isDiscontinued = false,
    this.replacedBy,
    this.repository,
    this.homepage,
    this.publisher,
    this.factualNotes = const [],
  });

  /// Package name.
  final String name;

  /// Known versions (newest last or unsorted — callers should not assume).
  final List<PackageVersionInfo> versions;

  /// Latest version according to the repository (may be pre-release).
  final Version? latest;

  /// Latest non-pre-release version.
  final Version? latestStable;

  /// Package description.
  final String? description;

  /// Whether pub.dev marks the package discontinued (factual).
  final bool isDiscontinued;

  /// Replacement package name when discontinued (factual).
  final String? replacedBy;

  /// Repository URL from latest pubspec when present (factual).
  final String? repository;

  /// Homepage URL from latest pubspec when present (factual).
  final String? homepage;

  /// Publisher id when known (factual when provided by API).
  final String? publisher;

  /// Additional factual notes (not popularity scores).
  final List<String> factualNotes;

  /// True when only pre-release versions exist beyond [latestStable].
  bool get preReleaseOnlyNewer {
    if (latest == null || latestStable == null) return false;
    return latest!.isPreRelease && latest! > latestStable!;
  }

  /// Age of the latest stable release, if publish timestamps exist.
  Duration? get latestStableAge {
    final stable = latestStable;
    if (stable == null) return null;
    final info = versionInfo(stable);
    final published = info?.published;
    if (published == null) return null;
    return DateTime.now().toUtc().difference(published.toUtc());
  }

  /// All non-retracted versions sorted ascending.
  List<Version> get sortedVersions {
    final list = versions
        .where((v) => !v.retracted)
        .map((v) => v.version)
        .toList()
      ..sort();
    return list;
  }

  /// Find metadata for a specific version.
  PackageVersionInfo? versionInfo(Version version) {
    for (final v in versions) {
      if (v.version == version) return v;
    }
    return null;
  }

  /// Latest version allowed by [constraint] and optional [sdk].
  Version? latestCompatible({
    VersionConstraint? constraint,
    Version? sdk,
  }) {
    Version? best;
    for (final info in versions) {
      if (info.retracted) continue;
      if (constraint != null && !constraint.allows(info.version)) continue;
      if (sdk != null &&
          info.sdkConstraint != null &&
          !info.sdkConstraint!.allows(sdk)) {
        continue;
      }
      if (best == null || info.version > best) {
        best = info.version;
      }
    }
    return best;
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (latest != null) 'latest': latest.toString(),
        if (latestStable != null) 'latestStable': latestStable.toString(),
        'isDiscontinued': isDiscontinued,
        if (replacedBy != null) 'replacedBy': replacedBy,
        if (repository != null) 'repository': repository,
        if (homepage != null) 'homepage': homepage,
        if (publisher != null) 'publisher': publisher,
        if (factualNotes.isNotEmpty) 'factualNotes': factualNotes,
        'preReleaseOnlyNewer': preReleaseOnlyNewer,
        'versions': versions.map((v) => v.toJson()).toList(),
      };
}

/// Why a package cannot upgrade to a desired version.
class UpgradeBlocker {
  /// Creates an upgrade blocker.
  const UpgradeBlocker({
    required this.package,
    required this.blockedBy,
    required this.constraint,
    required this.explanation,
    this.desiredVersion,
    this.path,
  });

  /// Package being upgraded.
  final String package;

  /// Package whose constraint blocks the upgrade.
  final String blockedBy;

  /// Blocking constraint.
  final VersionConstraint constraint;

  /// Explanation.
  final String explanation;

  /// Desired version, if any.
  final Version? desiredVersion;

  /// Path display string.
  final String? path;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'blockedBy': blockedBy,
        'constraint': constraint.toString(),
        'explanation': explanation,
        if (desiredVersion != null) 'desiredVersion': desiredVersion.toString(),
        if (path != null) 'path': path,
      };
}

/// Outdated package report with explanation.
class OutdatedPackage {
  /// Creates an outdated package report.
  const OutdatedPackage({
    required this.package,
    required this.current,
    this.declaredConstraint,
    this.latestCompatible,
    this.latest,
    this.latestStable,
    this.blockers = const [],
    this.explanation,
  });

  /// Package name.
  final String package;

  /// Currently resolved version.
  final Version current;

  /// Root-declared constraint when direct.
  final VersionConstraint? declaredConstraint;

  /// Newest version allowed by current constraints.
  final Version? latestCompatible;

  /// Newest available (any).
  final Version? latest;

  /// Newest stable available.
  final Version? latestStable;

  /// Blockers preventing latest/latestStable.
  final List<UpgradeBlocker> blockers;

  /// Human explanation of why upgrade is blocked (or not).
  final String? explanation;

  /// Whether an upgrade within constraints is available.
  bool get hasCompatibleUpgrade =>
      latestCompatible != null && latestCompatible! > current;

  /// Whether a newer version exists outside current constraints.
  bool get hasIncompatibleNewer =>
      latestStable != null &&
      latestStable! > current &&
      (latestCompatible == null || latestStable! > latestCompatible!);

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'current': current.toString(),
        if (declaredConstraint != null)
          'declaredConstraint': declaredConstraint.toString(),
        if (latestCompatible != null)
          'latestCompatible': latestCompatible.toString(),
        if (latest != null) 'latest': latest.toString(),
        if (latestStable != null) 'latestStable': latestStable.toString(),
        'blockers': blockers.map((b) => b.toJson()).toList(),
        if (explanation != null) 'explanation': explanation,
      };
}
