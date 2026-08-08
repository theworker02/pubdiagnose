import 'package:pub_semver/pub_semver.dart';

import 'dependency_spec.dart';

/// A single package entry from pubspec.lock.
class LockedPackage {
  /// Creates a locked package entry.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.dependency,
    required this.source,
    required this.description,
    this.sha256,
    this.dependencies = const {},
  });

  /// Package name.
  final String name;

  /// Resolved version.
  final Version version;

  /// Lockfile dependency classification (`direct main`, `direct dev`,
  /// `transitive`, `direct overridden`).
  final String dependency;

  /// Source type string from lockfile (`hosted`, `git`, `path`, `sdk`).
  final String source;

  /// Source description map (url, path, ref, etc.).
  final Map<String, Object?> description;

  /// Content hash when present.
  final String? sha256;

  /// Direct dependencies of this package as declared in the lockfile
  /// (`name` → constraint string), when available.
  final Map<String, String> dependencies;

  /// Whether this is a direct (main) dependency.
  bool get isDirectMain => dependency == 'direct main';

  /// Whether this is a direct dev dependency.
  bool get isDirectDev => dependency == 'direct dev';

  /// Whether this is transitive.
  bool get isTransitive => dependency == 'transitive';

  /// Whether this entry is overridden.
  bool get isOverridden => dependency.contains('overridden');

  /// Best-effort [DependencySource] mapping.
  DependencySource get dependencySource {
    switch (source) {
      case 'git':
        return DependencySource.git;
      case 'path':
        return DependencySource.path;
      case 'sdk':
        return DependencySource.sdk;
      default:
        return DependencySource.hosted;
    }
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        'version': version.toString(),
        'dependency': dependency,
        'source': source,
        'description': description,
        if (sha256 != null) 'sha256': sha256,
        if (dependencies.isNotEmpty) 'dependencies': dependencies,
      };
}

/// Parsed pubspec.lock.
class PubLockfile {
  /// Creates a lockfile model.
  const PubLockfile({
    required this.packages,
    this.sdks = const {},
    this.lockfileVersion,
  });

  /// Locked packages keyed by name.
  final Map<String, LockedPackage> packages;

  /// SDK versions recorded in the lockfile (`dart`, `flutter`).
  final Map<String, String> sdks;

  /// Lockfile format version when present.
  final int? lockfileVersion;

  /// Lookup by name.
  LockedPackage? operator [](String name) => packages[name];

  /// JSON representation.
  Map<String, Object?> toJson() => {
        if (lockfileVersion != null) 'lockfileVersion': lockfileVersion,
        'sdks': sdks,
        'packages': packages.map((k, v) => MapEntry(k, v.toJson())),
      };
}
