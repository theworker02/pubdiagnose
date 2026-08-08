/// Kind of independently distributable work.
enum WorkUnitKind {
  /// Fetch package metadata.
  packageMetadata,

  /// Analyze one workspace package.
  workspacePackage,

  /// Index source files.
  sourceIndex,

  /// Analyzer session chunk.
  analyzerSession,

  /// Policy evaluation.
  policyEvaluation,

  /// Risk analysis slice.
  riskAnalysis,

  /// Targeted test selection.
  testTargeting,
}

/// Explicit trust / data scope for a work unit.
enum TrustScope {
  /// Only package names / versions — no source.
  metadataOnly,

  /// Dependency graph model only.
  dependencyModel,

  /// Explicitly listed relative paths.
  selectedFiles,

  /// Full workspace tree (highest privilege).
  fullWorkspace,
}

/// A unit of work that can run on a local or remote worker.
class WorkUnit {
  /// Creates a work unit.
  const WorkUnit({
    required this.id,
    required this.kind,
    required this.inputFingerprint,
    this.scope = TrustScope.metadataOnly,
    this.payload = const {},
    this.selectedPaths = const [],
    this.protocolVersion = protocolVersionV1,
  });

  /// Current remote protocol version.
  static const protocolVersionV1 = 1;

  /// Stable id for this unit within a session.
  final String id;

  /// Work kind.
  final WorkUnitKind kind;

  /// Hash of inputs used for stale detection.
  final String inputFingerprint;

  /// Minimum data scope required.
  final TrustScope scope;

  /// JSON-serializable payload (no secrets).
  final Map<String, Object?> payload;

  /// Paths when [scope] is [TrustScope.selectedFiles].
  final List<String> selectedPaths;

  /// Protocol version the coordinator expects.
  final int protocolVersion;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'inputFingerprint': inputFingerprint,
        'scope': scope.name,
        'payload': payload,
        if (selectedPaths.isNotEmpty) 'selectedPaths': selectedPaths,
        'protocolVersion': protocolVersion,
      };

  /// Parse from JSON.
  factory WorkUnit.fromJson(Map<String, Object?> json) {
    return WorkUnit(
      id: json['id']! as String,
      kind: WorkUnitKind.values.byName(json['kind']! as String),
      inputFingerprint: json['inputFingerprint']! as String,
      scope: TrustScope.values.byName(
        (json['scope'] as String?) ?? TrustScope.metadataOnly.name,
      ),
      payload: Map<String, Object?>.from(
        (json['payload'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      selectedPaths: [
        for (final p in (json['selectedPaths'] as List?) ?? const [])
          p.toString(),
      ],
      protocolVersion:
          (json['protocolVersion'] as num?)?.toInt() ?? protocolVersionV1,
    );
  }
}
