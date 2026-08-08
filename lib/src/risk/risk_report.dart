import '../models/diagnostics.dart';
import 'dependency_risk.dart';
import 'risk_signal.dart';

/// A transitive package that many dependency paths pass through.
class ConcentrationPoint {
  /// Creates a concentration point.
  const ConcentrationPoint({
    required this.package,
    required this.pathCount,
    required this.parentCount,
    this.evidence = const [],
  });

  /// Package name.
  final String package;

  /// Approximate number of root→package paths considered.
  final int pathCount;

  /// Number of direct parents in the graph.
  final int parentCount;

  /// Evidence strings.
  final List<String> evidence;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'pathCount': pathCount,
        'parentCount': parentCount,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}

/// Full risk intelligence report.
class RiskReport {
  /// Creates a risk report.
  const RiskReport({
    required this.projectName,
    required this.packages,
    required this.signals,
    required this.concentration,
    this.diagnostics = const [],
    this.focusPackage,
  });

  /// Project package name.
  final String projectName;

  /// Per-package risks (packages with at least one signal, or focus).
  final List<DependencyRisk> packages;

  /// Flat signal list.
  final List<RiskSignal> signals;

  /// Graph chokepoints / concentration.
  final List<ConcentrationPoint> concentration;

  /// Diagnostics derived from signals.
  final List<Diagnostic> diagnostics;

  /// Optional package focus for `risk <package>`.
  final String? focusPackage;

  /// Worst category in the report.
  RiskCategory get worstCategory => DependencyRisk.worstOf(signals);

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'projectName': projectName,
        'worstCategory': worstCategory.name,
        if (focusPackage != null) 'focusPackage': focusPackage,
        'signalCount': signals.length,
        'packageCount': packages.length,
        'packages': [for (final p in packages) p.toJson()],
        'signals': [for (final s in signals) s.toJson()],
        'concentration': [for (final c in concentration) c.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };
}
