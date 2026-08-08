import 'risk_signal.dart';

/// Aggregated risk for a single dependency.
class DependencyRisk {
  /// Creates dependency risk.
  const DependencyRisk({
    required this.package,
    required this.signals,
    required this.worstCategory,
    this.isDirect = false,
    this.isTransitive = false,
    this.lockedVersion,
  });

  /// Package name.
  final String package;

  /// Signals for this package.
  final List<RiskSignal> signals;

  /// Worst category among signals (or unknown if empty).
  final RiskCategory worstCategory;

  /// Whether declared as a direct dependency.
  final bool isDirect;

  /// Whether present only transitively.
  final bool isTransitive;

  /// Locked version when known.
  final String? lockedVersion;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'package': package,
        'worstCategory': worstCategory.name,
        'isDirect': isDirect,
        'isTransitive': isTransitive,
        if (lockedVersion != null) 'lockedVersion': lockedVersion,
        'signals': [for (final s in signals) s.toJson()],
      };

  /// Worst category across [signals].
  static RiskCategory worstOf(Iterable<RiskSignal> signals) {
    var worst = RiskCategory.unknown;
    var rank = -1;
    for (final s in signals) {
      final r = _rank(s.category);
      if (r > rank) {
        rank = r;
        worst = s.category;
      }
    }
    return worst;
  }

  static int _rank(RiskCategory c) => switch (c) {
        RiskCategory.unknown => 0,
        RiskCategory.low => 1,
        RiskCategory.moderate => 2,
        RiskCategory.high => 3,
        RiskCategory.critical => 4,
      };
}
