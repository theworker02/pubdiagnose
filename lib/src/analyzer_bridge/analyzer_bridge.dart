/// Version-conscious analyzer bridge (lightweight / no hard analyzer dep).
///
/// Isolates future analyzer API churn from the rest of PubDoctor.
class AnalyzerBridge {
  /// Creates a bridge.
  AnalyzerBridge({this.analyzerVersion});

  /// Detected analyzer package version when available.
  final String? analyzerVersion;

  /// Compatibility notes for the current environment.
  Map<String, Object?> compatibility() => {
        'mode': 'lightweight',
        'analyzerVersion': analyzerVersion ?? 'not-linked',
        'supportsOfficialAnalyzerApis': false,
        'notes': [
          'PubDoctor uses a lightweight import/part indexer by default.',
          'Optional analyzer package integration can be added without '
              'leaking APIs into kernel/repair.',
        ],
      };

  /// Session stub.
  AnalyzerSession openSession(String workspacePath) =>
      AnalyzerSession(workspacePath: workspacePath, bridge: this);
}

/// Analyzer session abstraction.
class AnalyzerSession {
  /// Creates a session.
  AnalyzerSession({required this.workspacePath, required this.bridge});

  /// Workspace.
  final String workspacePath;

  /// Bridge.
  final AnalyzerBridge bridge;

  /// Best-effort analysis — lightweight bridge returns empty analyzer diags.
  Future<AnalyzerResult> analyze() async {
    return const AnalyzerResult(
      diagnostics: [],
      fixes: [],
      notes: [
        'lightweight bridge: use SourceChecker for project-level issues',
      ],
    );
  }
}

/// Analyzer result envelope.
class AnalyzerResult {
  /// Creates a result.
  const AnalyzerResult({
    required this.diagnostics,
    this.fixes = const [],
    this.notes = const [],
  });

  /// Diagnostics.
  final List<Map<String, Object?>> diagnostics;

  /// Suggested fixes from analyzer (when available).
  final List<AnalyzerFix> fixes;

  /// Notes.
  final List<String> notes;

  /// JSON.
  Map<String, Object?> toJson() => {
        'diagnostics': diagnostics,
        'fixes': [for (final f in fixes) f.toJson()],
        'notes': notes,
      };
}

/// Analyzer-provided fix descriptor.
class AnalyzerFix {
  /// Creates a fix.
  const AnalyzerFix({
    required this.id,
    required this.description,
  });

  /// Fix id.
  final String id;

  /// Description.
  final String description;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
      };
}

/// Compatibility helpers.
class AnalyzerCompatibility {
  /// Whether [version] is considered supported for bridge features.
  static bool supports(String? version) {
    if (version == null) return false;
    return version.startsWith('6.') ||
        version.startsWith('7.') ||
        version.startsWith('8.');
  }
}
