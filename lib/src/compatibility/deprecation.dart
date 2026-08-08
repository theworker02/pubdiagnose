/// Formal deprecation notices for flags, config, JSON, APIs, diagnostics.
class DeprecationNotice {
  /// Creates a notice.
  const DeprecationNotice({
    required this.id,
    required this.target,
    required this.message,
    this.replacement,
    this.removeAfterVersion,
  });

  /// Stable deprecation id.
  final String id;

  /// What is deprecated (flag name, API, diagnostic, …).
  final String target;

  /// Explanation.
  final String message;

  /// Suggested replacement.
  final String? replacement;

  /// Version after which removal may occur.
  final String? removeAfterVersion;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'target': target,
        'message': message,
        if (replacement != null) 'replacement': replacement,
        if (removeAfterVersion != null)
          'removeAfterVersion': removeAfterVersion,
      };
}

/// Registry of known deprecations.
abstract final class DeprecationRegistry {
  /// Active deprecations (none yet — structure ready for future).
  static const List<DeprecationNotice> active = [];

  /// Lookup by target.
  static List<DeprecationNotice> forTarget(String target) => [
        for (final d in active)
          if (d.target == target) d,
      ];
}
