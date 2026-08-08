import '../kernel/execution_context.dart';
import '../platform/platform_service.dart';
import '../version.dart';

/// Builds a sanitized crash / environment diagnostic report (no secrets).
class DoctorReportBuilder {
  /// Creates a builder.
  DoctorReportBuilder({
    required this.platform,
    this.context,
    this.includeSource = false,
  });

  /// Platform service.
  final PlatformService platform;

  /// Optional execution context.
  final ExecutionContext? context;

  /// When true, may include relative source paths (still no file bodies).
  final bool includeSource;

  /// Build sanitized report map.
  Map<String, Object?> build({
    Object? error,
    StackTrace? stackTrace,
  }) {
    final envKeys = platform.environment.all.keys.where(_isSafeEnvKey).toList()
      ..sort();

    return {
      'schemaVersion': 1,
      'tool': 'pubdoctor',
      'version': pubdoctorPackageVersion,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'platform': platform.toJson(),
      'safeEnvironmentKeys': envKeys,
      'capabilities': context?.capabilities.toJson(),
      'workspace':
          context == null ? null : _sanitizePath(context!.workspacePath),
      'cache': context?.cache.status(),
      'softDiagnostics': context == null
          ? const []
          : [
              for (final d in context!.softDiagnostics)
                {
                  'code': d.code,
                  'severity': d.severity.name,
                  'title': d.title,
                },
            ],
      if (error != null) 'error': _sanitizeError(error),
      if (stackTrace != null && includeSource)
        'stackTrace': stackTrace.toString().split('\n').take(40).toList(),
      if (stackTrace != null && !includeSource)
        'stackTraceFrames': stackTrace
            .toString()
            .split('\n')
            .take(20)
            .map(_stripUserPaths)
            .toList(),
      'notes': [
        'This report excludes secrets, tokens, and source file contents by default.',
        'Re-run with --include-source only when sharing paths intentionally.',
      ],
    };
  }

  bool _isSafeEnvKey(String key) {
    final upper = key.toUpperCase();
    const deny = [
      'TOKEN',
      'SECRET',
      'PASSWORD',
      'PASSWD',
      'API_KEY',
      'AUTH',
      'CREDENTIAL',
      'PRIVATE',
      'SSH',
      'COOKIE',
    ];
    for (final d in deny) {
      if (upper.contains(d)) return false;
    }
    const allow = [
      'PATH',
      'PATHEXT',
      'HOME',
      'USERPROFILE',
      'USERNAME',
      'USER',
      'SHELL',
      'TERM',
      'TEMP',
      'TMP',
      'TMPDIR',
      'CI',
      'PUB_CACHE',
      'FLUTTER_ROOT',
      'DART_SDK',
      'PROCESSOR_ARCHITECTURE',
      'NUMBER_OF_PROCESSORS',
      'OS',
      'LANG',
      'LC_ALL',
      'COLUMNS',
      'NO_COLOR',
      'FORCE_COLOR',
      'GITHUB_ACTIONS',
    ];
    return allow.contains(upper);
  }

  String _sanitizePath(String path) {
    // Keep only the basename chain depth hint — drop home directory bodies.
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 3).join('/')}';
  }

  String _sanitizeError(Object error) {
    return _stripUserPaths(error.toString());
  }

  String _stripUserPaths(String line) {
    return line
        .replaceAll(RegExp(r'[A-Za-z]:\\Users\\[^\\]+'), r'C:\Users\<user>')
        .replaceAll(RegExp(r'/Users/[^/]+'), '/Users/<user>')
        .replaceAll(RegExp(r'/home/[^/]+'), '/home/<user>');
  }
}
