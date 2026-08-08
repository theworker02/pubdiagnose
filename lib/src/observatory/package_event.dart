/// Ecosystem package event kinds.
enum PackageEventKind {
  /// New release published.
  release,

  /// Package discontinued.
  discontinued,

  /// Replacement declared.
  replacement,

  /// SDK support change.
  sdkSupport,

  /// Pre-release transition.
  prerelease,
}

/// Observed package ecosystem event.
class PackageEvent {
  /// Creates an event.
  const PackageEvent({
    required this.package,
    required this.kind,
    required this.summary,
    this.version,
    this.at,
  });

  /// Package name.
  final String package;

  /// Kind.
  final PackageEventKind kind;

  /// Summary.
  final String summary;

  /// Version if applicable.
  final String? version;

  /// When observed.
  final DateTime? at;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'kind': kind.name,
        'summary': summary,
        if (version != null) 'version': version,
        if (at != null) 'at': at!.toUtc().toIso8601String(),
      };
}

/// Release signal for a package.
class ReleaseSignal {
  /// Creates a signal.
  const ReleaseSignal({
    required this.package,
    this.currentProjectVersion,
    this.latestVersion,
    this.recentChanges = const [],
  });

  /// Package.
  final String package;

  /// Version in project.
  final String? currentProjectVersion;

  /// Latest known.
  final String? latestVersion;

  /// Recent change bullets.
  final List<String> recentChanges;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        if (currentProjectVersion != null)
          'currentProjectVersion': currentProjectVersion,
        if (latestVersion != null) 'latestVersion': latestVersion,
        'recentChanges': recentChanges,
      };
}

/// Compatibility signal (cautious forecasting).
class ObservatoryCompatibilitySignal {
  /// Creates a signal.
  const ObservatoryCompatibilitySignal({
    required this.package,
    required this.summary,
    this.likelyFutureBlocker = false,
    this.impact = 'unknown',
  });

  /// Package.
  final String package;

  /// Summary — use cautious language for forecasts.
  final String summary;

  /// Whether this is framed as a likely future blocker (not certain).
  final bool likelyFutureBlocker;

  /// Project impact estimate: low | moderate | high | unknown.
  final String impact;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'summary': summary,
        'likelyFutureBlocker': likelyFutureBlocker,
        'impact': impact,
      };
}

/// Deprecation / discontinuation signal.
class DeprecationSignal {
  /// Creates a signal.
  const DeprecationSignal({
    required this.package,
    required this.summary,
    this.replacement,
  });

  /// Package.
  final String package;

  /// Summary.
  final String summary;

  /// Replacement package if known.
  final String? replacement;

  /// JSON.
  Map<String, Object?> toJson() => {
        'package': package,
        'summary': summary,
        if (replacement != null) 'replacement': replacement,
      };
}
