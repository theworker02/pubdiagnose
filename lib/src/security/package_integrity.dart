/// Security-related diagnostic codes.
abstract final class SecurityCodes {
  /// Unexpected git dependency.
  static const gitDependency = 'PDSEC01';

  /// Non-default hosted source.
  static const externalHosted = 'PDSEC02';

  /// Path dependency escapes workspace.
  static const pathEscape = 'PDSEC03';

  /// Package source changed vs lockfile / prior.
  static const sourceDrift = 'PDSEC04';

  /// Lockfile internal incoherence.
  static const lockfileIntegrity = 'PDSEC05';

  /// Checksum mismatch when available.
  static const checksumMismatch = 'PDSEC06';
}

/// Security policy knobs (from pubdoctor.yaml `security:`).
class SecurityPolicy {
  /// Creates a policy.
  const SecurityPolicy({
    this.allowGitDependencies = true,
    this.allowExternalHostedSources = true,
    this.allowPathEscape = false,
  });

  /// Defaults (permissive unless tightened in config).
  static const defaults = SecurityPolicy();

  /// Allow git: dependencies.
  final bool allowGitDependencies;

  /// Allow hosted sources other than pub.dev.
  final bool allowExternalHostedSources;

  /// Allow path deps outside the workspace root.
  final bool allowPathEscape;

  /// JSON.
  Map<String, Object?> toJson() => {
        'allow_git_dependencies': allowGitDependencies,
        'allow_external_hosted_sources': allowExternalHostedSources,
        'allow_path_escape': allowPathEscape,
      };

  /// Parse from YAML-like map.
  factory SecurityPolicy.fromMap(Map<Object?, Object?>? map) {
    if (map == null) return SecurityPolicy.defaults;
    return SecurityPolicy(
      allowGitDependencies: map['allow_git_dependencies'] != false,
      allowExternalHostedSources: map['allow_external_hosted_sources'] != false,
      allowPathEscape: map['allow_path_escape'] == true,
    );
  }
}

/// Source trust classification for a dependency.
class DependencyTrust {
  /// Creates a trust record.
  const DependencyTrust({
    required this.package,
    required this.sourceKind,
    this.host,
    this.trusted = true,
    this.reason,
  });

  /// Package.
  final String package;

  /// hosted | git | path | sdk.
  final String sourceKind;

  /// Host URL for hosted.
  final String? host;

  /// Whether trusted under policy.
  final bool trusted;

  /// Reason when untrusted.
  final String? reason;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'sourceKind': sourceKind,
        if (host != null) 'host': host,
        'trusted': trusted,
        if (reason != null) 'reason': reason,
      };
}

/// Package integrity / source record.
class PackageIntegrity {
  /// Creates an integrity record.
  const PackageIntegrity({
    required this.package,
    required this.sourceKind,
    this.sha256,
    this.lockSource,
    this.pubspecSource,
  });

  /// Package.
  final String package;

  /// Source kind.
  final String sourceKind;

  /// Optional checksum.
  final String? sha256;

  /// Lockfile source description.
  final String? lockSource;

  /// Pubspec source description.
  final String? pubspecSource;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'sourceKind': sourceKind,
        if (sha256 != null) 'sha256': sha256,
        if (lockSource != null) 'lockSource': lockSource,
        if (pubspecSource != null) 'pubspecSource': pubspecSource,
      };
}
