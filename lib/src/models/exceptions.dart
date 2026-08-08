/// Exceptions thrown by pubdoctor when a project cannot be loaded or analyzed.
library;

/// Base class for all pubdoctor errors.
sealed class PubDoctorException implements Exception {
  /// Human-readable explanation.
  String get message;

  /// Optional machine-stable error code (e.g. PD1201).
  String? get code => null;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

/// The target directory is not a Dart package (missing pubspec.yaml).
final class MissingPubspecException extends PubDoctorException {
  MissingPubspecException(this.path);

  /// Absolute path that was searched.
  final String path;

  @override
  String get code => 'PD0001';

  @override
  String get message => 'No pubspec.yaml found at "$path".';
}

/// pubspec.yaml or pubspec.lock could not be parsed.
final class InvalidYamlException extends PubDoctorException {
  InvalidYamlException(this.path, this.cause);

  /// File that failed to parse.
  final String path;

  /// Underlying parse error.
  final Object cause;

  @override
  String get code => 'PD0002';

  @override
  String get message => 'Invalid YAML in "$path": $cause';
}

/// A required field or structure is missing/invalid in project files.
final class InvalidProjectException extends PubDoctorException {
  InvalidProjectException(this.message, {this.code = 'PD0003'});

  @override
  final String message;

  @override
  final String code;
}

/// Network or repository failure when fetching package metadata.
final class PackageRepositoryException extends PubDoctorException {
  PackageRepositoryException(
    this.message, {
    this.code = 'PD2001',
    this.cause,
    this.package,
  });

  @override
  final String message;

  @override
  final String code;

  /// Optional underlying cause.
  final Object? cause;

  /// Package that was requested, if known.
  final String? package;
}

/// Offline / unreachable repository.
final class OfflineRepositoryException extends PackageRepositoryException {
  OfflineRepositoryException({String? package, Object? cause})
      : super(
          package == null
              ? 'Package repository is unreachable (offline or timed out).'
              : 'Package repository is unreachable while fetching "$package".',
          code: 'PD2002',
          cause: cause,
          package: package,
        );
}

/// Package was not found on the repository.
final class PackageNotFoundException extends PackageRepositoryException {
  PackageNotFoundException(String package)
      : super(
          'Package "$package" was not found on the repository.',
          code: 'PD1201',
          package: package,
        );
}
