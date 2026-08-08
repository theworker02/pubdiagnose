import 'dart:io' as io show Platform;

/// Portable environment variable access.
class EnvironmentAdapter {
  /// Creates an adapter over [environment] (defaults to process env).
  EnvironmentAdapter([Map<String, String>? environment])
      : _env = Map.unmodifiable(environment ?? io.Platform.environment);

  final Map<String, String> _env;

  /// All variables (read-only snapshot).
  Map<String, String> get all => _env;

  /// Lookup [name], or null.
  String? operator [](String name) => _env[name];

  /// Lookup with default.
  String getOr(String name, String defaultValue) => _env[name] ?? defaultValue;

  /// HOME / USERPROFILE (may be missing in restricted envs).
  String? get home {
    final h = _env['HOME'] ?? _env['USERPROFILE'];
    if (h != null && h.isNotEmpty) return h;
    return null;
  }

  /// PUB_CACHE if set.
  String? get pubCache => _env['PUB_CACHE'];

  /// TEMP / TMPDIR / TMP.
  String? get temp {
    for (final k in ['TMPDIR', 'TEMP', 'TMP']) {
      final v = _env[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// PATH / Path.
  String? get path => _env['PATH'] ?? _env['Path'];

  /// Shell name hint (ComSpec, SHELL, PSModulePath presence).
  String shellHint() {
    final shell = _env['SHELL'];
    if (shell != null && shell.isNotEmpty) {
      final base = shell.replaceAll('\\', '/').split('/').last.toLowerCase();
      if (base.contains('zsh')) return 'zsh';
      if (base.contains('fish')) return 'fish';
      if (base.contains('bash')) return 'bash';
      return base;
    }
    if (_env['PSModulePath'] != null) return 'powershell';
    if (_env['ComSpec'] != null) return 'cmd';
    return 'unknown';
  }

  /// Whether [name] is set non-empty.
  bool has(String name) {
    final v = _env[name];
    return v != null && v.isNotEmpty;
  }
}
