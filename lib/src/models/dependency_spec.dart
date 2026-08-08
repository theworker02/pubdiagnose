import 'package:pub_semver/pub_semver.dart';

/// Which pubspec section a dependency comes from.
enum DependencySection {
  /// `dependencies:`
  dependency,

  /// `dev_dependencies:`
  devDependency,

  /// `dependency_overrides:`
  override,
}

/// How a dependency is sourced.
enum DependencySource {
  /// Hosted on pub.dev or a custom hosted URL.
  hosted,

  /// Git repository.
  git,

  /// Local path.
  path,

  /// SDK (Dart or Flutter).
  sdk,
}

/// A declared dependency from pubspec.yaml.
class DependencySpec {
  /// Creates a dependency specification.
  const DependencySpec({
    required this.name,
    required this.constraint,
    required this.source,
    required this.section,
    this.hostedUrl,
    this.path,
    this.gitUrl,
    this.gitRef,
    this.gitPath,
    this.sdk,
    this.raw,
  });

  /// Package name.
  final String name;

  /// Version constraint (`any` when unconstrained / non-versioned sources).
  final VersionConstraint constraint;

  /// Source kind.
  final DependencySource source;

  /// Pubspec section.
  final DependencySection section;

  /// Custom hosted URL, if any.
  final String? hostedUrl;

  /// Path for path dependencies.
  final String? path;

  /// Git URL.
  final String? gitUrl;

  /// Git ref (branch/tag/commit).
  final String? gitRef;

  /// Path within the git repo.
  final String? gitPath;

  /// SDK name (`dart` / `flutter`).
  final String? sdk;

  /// Original YAML fragment for debugging.
  final Object? raw;

  /// Whether this is an override entry.
  bool get isOverride => section == DependencySection.override;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        'constraint': constraint.toString(),
        'source': source.name,
        'section': section.name,
        if (hostedUrl != null) 'hostedUrl': hostedUrl,
        if (path != null) 'path': path,
        if (gitUrl != null) 'gitUrl': gitUrl,
        if (gitRef != null) 'gitRef': gitRef,
        if (gitPath != null) 'gitPath': gitPath,
        if (sdk != null) 'sdk': sdk,
      };

  @override
  String toString() =>
      'DependencySpec($name ${constraint.toString()} ${source.name}/${section.name})';
}

/// Environment SDK constraints from pubspec.
class SdkEnvironment {
  /// Creates SDK environment constraints.
  const SdkEnvironment({this.sdk, this.flutter});

  /// Dart SDK constraint (`environment.sdk`).
  final VersionConstraint? sdk;

  /// Flutter SDK constraint (`environment.flutter`), if present.
  final VersionConstraint? flutter;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        if (sdk != null) 'sdk': sdk.toString(),
        if (flutter != null) 'flutter': flutter.toString(),
      };
}
