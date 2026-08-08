import '../healing/healing_policy.dart';
import '../repair/repair_plan.dart';

/// Verification stage.
enum VerificationStage {
  /// Syntax / YAML.
  syntax,

  /// Analyzer.
  analyzer,

  /// Dependency resolution.
  resolution,

  /// Targeted tests.
  targetedTests,

  /// Full tests.
  fullTests,

  /// PubDoctor diagnostics.
  pubdoctor,

  /// Before/after regression.
  regression,
}

/// Result of one stage.
class StageResult {
  /// Creates a result.
  const StageResult({
    required this.stage,
    required this.ok,
    this.message,
    this.metrics = const {},
  });

  /// Stage.
  final VerificationStage stage;

  /// Ok.
  final bool ok;

  /// Message.
  final String? message;

  /// Metrics.
  final Map<String, Object?> metrics;

  /// JSON.
  Map<String, Object?> toJson() => {
        'stage': stage.name,
        'ok': ok,
        if (message != null) 'message': message,
        if (metrics.isNotEmpty) 'metrics': metrics,
      };
}

/// Aggregated verification result.
class VerificationResult {
  /// Creates a result.
  const VerificationResult({
    required this.ok,
    required this.stages,
    this.regression = false,
    this.message,
  });

  /// Overall ok.
  final bool ok;

  /// Stages.
  final List<StageResult> stages;

  /// Regression detected.
  final bool regression;

  /// Message.
  final String? message;

  /// JSON.
  Map<String, Object?> toJson() => {
        'ok': ok,
        'regression': regression,
        if (message != null) 'message': message,
        'stages': [for (final s in stages) s.toJson()],
      };
}

/// Detects regressions from before/after metrics.
class RegressionDetector {
  /// True if after is worse.
  bool isRegression({
    required int beforeErrors,
    required int afterErrors,
  }) =>
      afterErrors > beforeErrors;
}

/// Scores repair candidates (prefer minimal).
class ConfidenceEvaluator {
  /// Score candidate (higher is better).
  double score(RepairCandidate c) {
    var s = switch (c.confidence) {
      RepairConfidence.certain => 100.0,
      RepairConfidence.high => 80.0,
      RepairConfidence.medium => 50.0,
      RepairConfidence.low => 20.0,
      RepairConfidence.unknown => 0.0,
    };
    if (c.ambiguous) s -= 100;
    if (c.tier == SafetyTier.t4Behavioral) s -= 1000;
    s -= c.operations.length * 2;
    return s;
  }

  /// Pick best among [candidates] with strict limit.
  RepairCandidate? best(
    List<RepairCandidate> candidates, {
    int limit = 5,
  }) {
    final sorted = [...candidates]
      ..sort((a, b) => score(b).compareTo(score(a)));
    if (sorted.isEmpty) return null;
    return sorted.take(limit).first;
  }
}

/// Multi-layer verification controller.
class VerificationController {
  /// Creates a controller.
  VerificationController({
    this.allowProcess = false,
  });

  /// Whether external processes may run.
  final bool allowProcess;

  final _regression = RegressionDetector();
  final _confidence = ConfidenceEvaluator();

  /// Access scoring.
  ConfidenceEvaluator get confidence => _confidence;

  /// Verify a metadata repair using local checks.
  VerificationResult verifyMetadata({
    required String? pubspecText,
    required int beforeDiagnostics,
    required int afterDiagnostics,
  }) {
    final stages = <StageResult>[
      StageResult(
        stage: VerificationStage.syntax,
        ok: pubspecText != null && pubspecText.contains('name:'),
        message: pubspecText == null ? 'missing pubspec' : 'yaml present',
      ),
      StageResult(
        stage: VerificationStage.pubdoctor,
        ok: afterDiagnostics <= beforeDiagnostics,
        metrics: {
          'before': beforeDiagnostics,
          'after': afterDiagnostics,
        },
      ),
      StageResult(
        stage: VerificationStage.regression,
        ok: !_regression.isRegression(
          beforeErrors: beforeDiagnostics,
          afterErrors: afterDiagnostics,
        ),
        message: afterDiagnostics > beforeDiagnostics
            ? 'repair produced a regression'
            : 'no regression',
      ),
    ];
    final ok = stages.every((s) => s.ok);
    return VerificationResult(
      ok: ok,
      stages: stages,
      regression: stages.any(
        (s) => s.stage == VerificationStage.regression && !s.ok,
      ),
      message: ok ? 'verification passed' : 'verification failed',
    );
  }

  /// Compete candidates in-memory (no unbounded search).
  RepairCandidate? compete(List<RepairCandidate> candidates) =>
      _confidence.best(candidates, limit: 5);
}

/// Internal architecture audit.
class InternalAudit {
  /// Audit registries for orphans / consistency.
  static Map<String, Object?> run({
    required List<String> featureIds,
    required List<String> commandNames,
    required List<String> diagnosticCodes,
  }) {
    final missingCommands = <String>[];
    const expected = [
      'check',
      'risk',
      'migrate',
      'policy',
      'impact',
      'snapshot',
      'drift',
      'health',
      'heal',
      'repair',
      'environment',
      'watch',
      'audit',
    ];
    for (final e in expected) {
      if (!commandNames.contains(e) && !featureIds.contains(e)) {
        missingCommands.add(e);
      }
    }
    return {
      'featureCount': featureIds.length,
      'commandCount': commandNames.length,
      'diagnosticCount': diagnosticCodes.length,
      'missingExpected': missingCommands,
      'ok': missingCommands.isEmpty,
    };
  }
}
