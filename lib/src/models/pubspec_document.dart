import 'package:pub_semver/pub_semver.dart';

import 'dependency_spec.dart';

/// Parsed pubspec.yaml document.
class PubspecDocument {
  /// Creates a pubspec document model.
  const PubspecDocument({
    required this.name,
    required this.version,
    required this.environment,
    required this.dependencies,
    required this.devDependencies,
    required this.dependencyOverrides,
    this.description,
    this.publishTo,
  });

  /// Package name.
  final String name;

  /// Package version, if declared.
  final Version? version;

  /// Package description.
  final String? description;

  /// `publish_to` field.
  final String? publishTo;

  /// SDK environment.
  final SdkEnvironment environment;

  /// Production dependencies.
  final List<DependencySpec> dependencies;

  /// Dev dependencies.
  final List<DependencySpec> devDependencies;

  /// Dependency overrides.
  final List<DependencySpec> dependencyOverrides;

  /// All non-override dependencies.
  Iterable<DependencySpec> get allDependencies sync* {
    yield* dependencies;
    yield* devDependencies;
  }

  /// Lookup a declared dependency by name (preferring production over dev).
  DependencySpec? dependency(String name) {
    for (final d in dependencies) {
      if (d.name == name) return d;
    }
    for (final d in devDependencies) {
      if (d.name == name) return d;
    }
    return null;
  }

  /// Lookup an override by name.
  DependencySpec? overrideFor(String name) {
    for (final d in dependencyOverrides) {
      if (d.name == name) return d;
    }
    return null;
  }

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        if (version != null) 'version': version.toString(),
        if (description != null) 'description': description,
        if (publishTo != null) 'publishTo': publishTo,
        'environment': environment.toJson(),
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        'devDependencies': devDependencies.map((d) => d.toJson()).toList(),
        'dependencyOverrides':
            dependencyOverrides.map((d) => d.toJson()).toList(),
      };
}
