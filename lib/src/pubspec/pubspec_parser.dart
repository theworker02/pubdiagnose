import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../models/dependency_spec.dart';
import '../models/exceptions.dart';
import '../models/pubspec_document.dart';

/// Parses `pubspec.yaml` content into a [PubspecDocument].
class PubspecParser {
  /// Parses YAML text from [source] (usually a file path for errors).
  PubspecDocument parse(String content, {String source = 'pubspec.yaml'}) {
    late final YamlNode rootNode;
    try {
      rootNode = loadYamlNode(content);
    } on Object catch (e) {
      throw InvalidYamlException(source, e);
    }

    if (rootNode is! YamlMap) {
      throw InvalidProjectException(
        'pubspec.yaml root must be a map ($source).',
      );
    }

    final map = rootNode;
    final name = map['name'];
    if (name is! String || name.isEmpty) {
      throw InvalidProjectException(
        'pubspec.yaml is missing a valid "name" field ($source).',
      );
    }

    Version? version;
    final versionRaw = map['version'];
    if (versionRaw is String && versionRaw.isNotEmpty) {
      try {
        version = Version.parse(versionRaw);
      } on FormatException catch (e) {
        throw InvalidProjectException(
          'Invalid package version "$versionRaw" in $source: $e',
        );
      }
    }

    final environment = _parseEnvironment(map['environment'], source);
    final dependencies = _parseSection(
      map['dependencies'],
      DependencySection.dependency,
      source,
    );
    final devDependencies = _parseSection(
      map['dev_dependencies'],
      DependencySection.devDependency,
      source,
    );
    final overrides = _parseSection(
      map['dependency_overrides'],
      DependencySection.override,
      source,
    );

    return PubspecDocument(
      name: name,
      version: version,
      description:
          map['description'] is String ? map['description'] as String : null,
      publishTo:
          map['publish_to'] is String ? map['publish_to'] as String : null,
      environment: environment,
      dependencies: dependencies,
      devDependencies: devDependencies,
      dependencyOverrides: overrides,
    );
  }

  SdkEnvironment _parseEnvironment(Object? raw, String source) {
    if (raw == null) {
      return const SdkEnvironment();
    }
    if (raw is! YamlMap) {
      throw InvalidProjectException(
        'environment must be a map in $source.',
      );
    }
    return SdkEnvironment(
      sdk: _parseConstraint(raw['sdk'],
          field: 'environment.sdk', source: source),
      flutter: _parseConstraint(
        raw['flutter'],
        field: 'environment.flutter',
        source: source,
        optional: true,
      ),
    );
  }

  List<DependencySpec> _parseSection(
    Object? raw,
    DependencySection section,
    String source,
  ) {
    if (raw == null) return const [];
    if (raw is! YamlMap) {
      throw InvalidProjectException(
        '${section.name} must be a map in $source.',
      );
    }
    final result = <DependencySpec>[];
    for (final entry in raw.entries) {
      final name = entry.key;
      if (name is! String) continue;
      result.add(_parseDependency(name, entry.value, section, source));
    }
    return result;
  }

  DependencySpec _parseDependency(
    String name,
    Object? value,
    DependencySection section,
    String source,
  ) {
    if (value == null || value == 'any') {
      return DependencySpec(
        name: name,
        constraint: VersionConstraint.any,
        source: DependencySource.hosted,
        section: section,
        raw: value,
      );
    }

    if (value is String) {
      return DependencySpec(
        name: name,
        constraint: _mustParseConstraint(value, name, source),
        source: DependencySource.hosted,
        section: section,
        raw: value,
      );
    }

    if (value is num) {
      return DependencySpec(
        name: name,
        constraint: _mustParseConstraint(value.toString(), name, source),
        source: DependencySource.hosted,
        section: section,
        raw: value,
      );
    }

    if (value is! YamlMap) {
      throw InvalidProjectException(
        'Invalid dependency entry for "$name" in $source.',
      );
    }

    final map = value;

    if (map.containsKey('sdk')) {
      final sdk = map['sdk'];
      return DependencySpec(
        name: name,
        constraint: _parseConstraint(
              map['version'],
              field: '$name.version',
              source: source,
              optional: true,
            ) ??
            VersionConstraint.any,
        source: DependencySource.sdk,
        section: section,
        sdk: sdk?.toString(),
        raw: _yamlToPlain(map),
      );
    }

    if (map.containsKey('path')) {
      return DependencySpec(
        name: name,
        constraint: VersionConstraint.any,
        source: DependencySource.path,
        section: section,
        path: map['path']?.toString(),
        raw: _yamlToPlain(map),
      );
    }

    if (map.containsKey('git')) {
      final git = map['git'];
      if (git is String) {
        return DependencySpec(
          name: name,
          constraint: VersionConstraint.any,
          source: DependencySource.git,
          section: section,
          gitUrl: git,
          raw: _yamlToPlain(map),
        );
      }
      if (git is YamlMap) {
        return DependencySpec(
          name: name,
          constraint: VersionConstraint.any,
          source: DependencySource.git,
          section: section,
          gitUrl: git['url']?.toString(),
          gitRef: git['ref']?.toString(),
          gitPath: git['path']?.toString(),
          raw: _yamlToPlain(map),
        );
      }
      throw InvalidProjectException(
        'Invalid git dependency for "$name" in $source.',
      );
    }

    // Hosted (possibly custom URL).
    String? hostedUrl;
    VersionConstraint constraint = VersionConstraint.any;

    if (map.containsKey('hosted')) {
      final hosted = map['hosted'];
      if (hosted is String) {
        hostedUrl = hosted;
      } else if (hosted is YamlMap) {
        hostedUrl = (hosted['url'] ?? hosted['name'])?.toString();
      }
    }

    if (map.containsKey('version')) {
      constraint = _parseConstraint(
            map['version'],
            field: '$name.version',
            source: source,
          ) ??
          VersionConstraint.any;
    }

    return DependencySpec(
      name: name,
      constraint: constraint,
      source: DependencySource.hosted,
      section: section,
      hostedUrl: hostedUrl,
      raw: _yamlToPlain(map),
    );
  }

  VersionConstraint? _parseConstraint(
    Object? raw, {
    required String field,
    required String source,
    bool optional = false,
  }) {
    if (raw == null) {
      if (optional) return null;
      return VersionConstraint.any;
    }
    try {
      return VersionConstraint.parse(raw.toString());
    } on FormatException catch (e) {
      throw InvalidProjectException(
        'Invalid version constraint for $field in $source: $e',
      );
    }
  }

  VersionConstraint _mustParseConstraint(
    String raw,
    String name,
    String source,
  ) {
    try {
      return VersionConstraint.parse(raw);
    } on FormatException catch (e) {
      throw InvalidProjectException(
        'Invalid version constraint for "$name" in $source: $e',
      );
    }
  }

  Object? _yamlToPlain(Object? node) {
    if (node is YamlMap) {
      return {
        for (final e in node.entries) e.key.toString(): _yamlToPlain(e.value),
      };
    }
    if (node is YamlList) {
      return node.map(_yamlToPlain).toList();
    }
    return node;
  }
}
