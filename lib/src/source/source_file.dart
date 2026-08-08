/// Location in a source file.
class SourceLocation {
  /// Creates a location.
  const SourceLocation({
    required this.path,
    this.line,
    this.column,
  });

  /// Relative path.
  final String path;

  /// 1-based line.
  final int? line;

  /// 1-based column.
  final int? column;

  /// JSON.
  Map<String, Object?> toJson() => {
        'path': path,
        if (line != null) 'line': line,
        if (column != null) 'column': column,
      };
}

/// A proposed source text change.
class SourceChange {
  /// Creates a change.
  const SourceChange({
    required this.path,
    required this.description,
    this.replacement,
    this.confidence = 'medium',
  });

  /// File path.
  final String path;

  /// Description.
  final String description;

  /// Full-file replacement when known.
  final String? replacement;

  /// Confidence label.
  final String confidence;

  /// JSON.
  Map<String, Object?> toJson() => {
        'path': path,
        'description': description,
        'confidence': confidence,
        if (replacement != null) 'hasReplacement': true,
      };
}

/// Source-level diagnostic.
class SourceDiagnostic {
  /// Creates a diagnostic.
  const SourceDiagnostic({
    required this.code,
    required this.message,
    required this.location,
    this.package,
    this.evidence = const [],
    this.repairHint,
  });

  /// Code (e.g. PDS101).
  final String code;

  /// Message.
  final String message;

  /// Location.
  final SourceLocation location;

  /// Related package.
  final String? package;

  /// Evidence.
  final List<String> evidence;

  /// Repair hint.
  final String? repairHint;

  /// JSON.
  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        'location': location.toJson(),
        if (package != null) 'package': package,
        if (evidence.isNotEmpty) 'evidence': evidence,
        if (repairHint != null) 'repairHint': repairHint,
      };
}

/// Indexed Dart source file (lightweight).
class SourceFile {
  /// Creates a source file record.
  const SourceFile({
    required this.path,
    required this.packageImports,
    this.relativeImports = const [],
    this.parts = const [],
    this.partOf,
    this.isGenerated = false,
  });

  /// Relative path.
  final String path;

  /// package: imports.
  final Set<String> packageImports;

  /// Relative import URIs.
  final List<String> relativeImports;

  /// part directives.
  final List<String> parts;

  /// part of URI if any.
  final String? partOf;

  /// Generated file.
  final bool isGenerated;

  /// JSON.
  Map<String, Object?> toJson() => {
        'path': path,
        'packageImports': packageImports.toList()..sort(),
        'relativeImports': relativeImports,
        'parts': parts,
        if (partOf != null) 'partOf': partOf,
        'isGenerated': isGenerated,
      };
}
