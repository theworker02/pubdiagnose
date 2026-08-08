import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../models/exceptions.dart';
import '../models/lockfile.dart';

/// Parses `pubspec.lock` content into a [PubLockfile].
class LockfileParser {
  /// Parses lockfile YAML text.
  PubLockfile parse(String content, {String source = 'pubspec.lock'}) {
    late final YamlNode rootNode;
    try {
      rootNode = loadYamlNode(content);
    } on Object catch (e) {
      throw InvalidYamlException(source, e);
    }

    if (rootNode is! YamlMap) {
      throw InvalidProjectException(
        'pubspec.lock root must be a map ($source).',
      );
    }

    final map = rootNode;
    final packagesRaw = map['packages'];
    final packages = <String, LockedPackage>{};

    if (packagesRaw is YamlMap) {
      for (final entry in packagesRaw.entries) {
        final name = entry.key;
        if (name is! String) continue;
        final value = entry.value;
        if (value is! YamlMap) continue;
        packages[name] = _parsePackage(name, value, source);
      }
    }

    final sdks = <String, String>{};
    final sdksRaw = map['sdks'];
    if (sdksRaw is YamlMap) {
      for (final entry in sdksRaw.entries) {
        if (entry.key is String && entry.value != null) {
          sdks[entry.key as String] = entry.value.toString();
        }
      }
    }

    int? lockfileVersion;
    final versionRaw = map['version'];
    if (versionRaw is int) {
      lockfileVersion = versionRaw;
    } else if (versionRaw is String) {
      lockfileVersion = int.tryParse(versionRaw);
    }

    return PubLockfile(
      packages: packages,
      sdks: sdks,
      lockfileVersion: lockfileVersion,
    );
  }

  LockedPackage _parsePackage(String name, YamlMap map, String source) {
    final versionRaw = map['version']?.toString();
    if (versionRaw == null || versionRaw.isEmpty) {
      throw InvalidProjectException(
        'Package "$name" in $source is missing a version.',
      );
    }

    late final Version version;
    try {
      version = Version.parse(versionRaw);
    } on FormatException catch (e) {
      throw InvalidProjectException(
        'Invalid version for "$name" in $source: $e',
      );
    }

    final dependency = map['dependency']?.toString() ?? 'transitive';
    final sourceKind = map['source']?.toString() ?? 'hosted';

    final description = <String, Object?>{};
    final descRaw = map['description'];
    if (descRaw is YamlMap) {
      for (final e in descRaw.entries) {
        description[e.key.toString()] = _plain(e.value);
      }
    } else if (descRaw != null) {
      description['value'] = _plain(descRaw);
    }

    String? sha256;
    final hash = description['sha256'];
    if (hash is String) {
      sha256 = hash;
    }

    final deps = <String, String>{};
    final depsRaw = map['dependencies'];
    if (depsRaw is YamlMap) {
      for (final e in depsRaw.entries) {
        if (e.key is String) {
          deps[e.key as String] = e.value?.toString() ?? 'any';
        }
      }
    }

    return LockedPackage(
      name: name,
      version: version,
      dependency: dependency,
      source: sourceKind,
      description: description,
      sha256: sha256,
      dependencies: deps,
    );
  }

  Object? _plain(Object? node) {
    if (node is YamlMap) {
      return {
        for (final e in node.entries) e.key.toString(): _plain(e.value),
      };
    }
    if (node is YamlList) {
      return node.map(_plain).toList();
    }
    return node;
  }
}
