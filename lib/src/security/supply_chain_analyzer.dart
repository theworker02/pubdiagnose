import '../models/dependency_spec.dart';
import '../models/diagnostics.dart';
import '../models/lockfile.dart';
import '../workspace/workspace_loader.dart';
import 'package_integrity.dart';

/// Validates optional package checksums when present in metadata.
class ChecksumValidator {
  /// Compare expected vs actual; returns diagnostic when mismatched.
  Diagnostic? validate({
    required String package,
    String? expected,
    String? actual,
  }) {
    if (expected == null || actual == null) return null;
    if (expected == actual) return null;
    return Diagnostic(
      code: SecurityCodes.checksumMismatch,
      title: 'Checksum mismatch',
      message:
          'Package `$package` checksum does not match expected integrity hash.',
      severity: DiagnosticSeverity.error,
      package: package,
      evidence: ['expected=$expected', 'actual=$actual'],
      remediation:
          'Re-resolve from a trusted source; do not ignore mismatches.',
    );
  }
}

/// Policy helpers for dependency sources.
class SourcePolicy {
  /// Creates a source policy evaluator.
  const SourcePolicy(this.policy);

  /// Security policy.
  final SecurityPolicy policy;

  /// Default pub.dev hosts.
  static const defaultHosts = {
    'pub.dev',
    'pub.dartlang.org',
  };

  /// Whether [host] is a default hosted registry.
  static bool isDefaultHost(String? host) {
    if (host == null || host.isEmpty) return true;
    final h = host.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    return defaultHosts.contains(h);
  }
}

/// Supply-chain / dependency source analyzer.
class SupplyChainAnalyzer {
  /// Creates an analyzer.
  SupplyChainAnalyzer({
    required this.workspace,
    this.policy = SecurityPolicy.defaults,
  });

  /// Workspace.
  final PubWorkspace workspace;

  /// Policy.
  final SecurityPolicy policy;

  /// Analyze sources + lockfile coherence.
  List<Diagnostic> analyze() {
    final out = <Diagnostic>[];
    out.addAll(_sourceChecks());
    out.addAll(lockfileIntegrity());
    return out;
  }

  /// Lockfile internal coherence checks.
  List<Diagnostic> lockfileIntegrity() {
    final lock = workspace.lockfile;
    if (lock == null) {
      return [
        const Diagnostic(
          code: SecurityCodes.lockfileIntegrity,
          title: 'Missing lockfile',
          message: 'No pubspec.lock — cannot verify resolved integrity.',
          severity: DiagnosticSeverity.warning,
          remediation: 'Run `dart pub get` to produce a lockfile.',
        ),
      ];
    }
    final out = <Diagnostic>[];
    final declared = {
      ...workspace.pubspec.dependencies.map((d) => d.name),
      ...workspace.pubspec.devDependencies.map((d) => d.name),
    };
    for (final name in declared) {
      if (!lock.packages.containsKey(name)) {
        final spec = _findSpec(name);
        if (spec != null && spec.source == DependencySource.hosted) {
          out.add(
            Diagnostic(
              code: SecurityCodes.lockfileIntegrity,
              title: 'Lockfile missing package',
              message:
                  'Declared dependency `$name` is not present in pubspec.lock.',
              severity: DiagnosticSeverity.warning,
              package: name,
              remediation: 'Run `dart pub get` and review resolution.',
            ),
          );
        }
      }
    }

    for (final pkg in lock.packages.values) {
      final spec = _findSpec(pkg.name);
      if (spec == null) continue;
      final lockDesc = _lockSourceDesc(pkg);
      final specDesc = _specSourceDesc(spec);
      if (!_sourcesCompatible(specDesc, lockDesc)) {
        out.add(
          Diagnostic(
            code: SecurityCodes.sourceDrift,
            title: 'Package source changed',
            message:
                'SECURITY WARNING: Package `${pkg.name}` previously resolved '
                'as $lockDesc. Current pubspec resolves `${pkg.name}` from: '
                '$specDesc. Source changed. Review required.',
            severity: DiagnosticSeverity.error,
            package: pkg.name,
            evidence: ['lock=$lockDesc', 'pubspec=$specDesc'],
            remediation:
                'Never silently change package sources. Review and update '
                'deliberately; security fixes must not auto-rewrite sources.',
          ),
        );
      }
    }
    return out;
  }

  List<Diagnostic> _sourceChecks() {
    final out = <Diagnostic>[];
    final all = [
      ...workspace.pubspec.dependencies,
      ...workspace.pubspec.devDependencies,
      ...workspace.pubspec.dependencyOverrides,
    ];
    for (final dep in all) {
      if (dep.source == DependencySource.git && !policy.allowGitDependencies) {
        out.add(
          Diagnostic(
            code: SecurityCodes.gitDependency,
            title: 'Git dependency disallowed',
            message:
                'Package `${dep.name}` uses a git source, forbidden by security policy.',
            severity: DiagnosticSeverity.error,
            package: dep.name,
            remediation:
                'Pin a hosted version or explicitly allow git in policy.',
          ),
        );
      }
      if (dep.source == DependencySource.hosted &&
          !SourcePolicy.isDefaultHost(dep.hostedUrl) &&
          !policy.allowExternalHostedSources) {
        out.add(
          Diagnostic(
            code: SecurityCodes.externalHosted,
            title: 'External hosted source',
            message: 'Package `${dep.name}` resolves from non-default registry '
                '`${dep.hostedUrl}`.',
            severity: DiagnosticSeverity.error,
            package: dep.name,
            remediation:
                'Use pub.dev or allow external hosted sources in policy.',
          ),
        );
      }
      if (dep.source == DependencySource.path && !policy.allowPathEscape) {
        final path = dep.path;
        if (path != null && _escapesWorkspace(path)) {
          out.add(
            Diagnostic(
              code: SecurityCodes.pathEscape,
              title: 'Path dependency escapes workspace',
              message:
                  'Package `${dep.name}` path `$path` leaves the workspace root.',
              severity: DiagnosticSeverity.error,
              package: dep.name,
              remediation: 'Keep path dependencies inside the workspace.',
            ),
          );
        }
      }
    }
    return out;
  }

  bool _escapesWorkspace(String path) {
    if (path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
      return true;
    }
    final parts = path.replaceAll('\\', '/').split('/');
    var depth = 0;
    for (final p in parts) {
      if (p == '..') {
        depth--;
        if (depth < 0) return true;
      } else if (p != '.' && p.isNotEmpty) {
        depth++;
      }
    }
    return false;
  }

  DependencySpec? _findSpec(String name) {
    for (final d in [
      ...workspace.pubspec.dependencies,
      ...workspace.pubspec.devDependencies,
      ...workspace.pubspec.dependencyOverrides,
    ]) {
      if (d.name == name) return d;
    }
    return null;
  }

  String _lockSourceDesc(LockedPackage pkg) {
    if (pkg.source == 'hosted') {
      final url = pkg.description['url']?.toString() ?? 'pub.dev';
      return 'hosted:$url';
    }
    return pkg.source;
  }

  String _specSourceDesc(DependencySpec spec) {
    switch (spec.source) {
      case DependencySource.git:
        return 'git';
      case DependencySource.path:
        return 'path:${spec.path}';
      case DependencySource.sdk:
        return 'sdk';
      case DependencySource.hosted:
        return 'hosted:${spec.hostedUrl ?? 'pub.dev'}';
    }
  }

  bool _sourcesCompatible(String a, String b) {
    if (a == b) return true;
    // Comparing path vs path:… is only drift when kinds differ.
    String kind(String s) => s.split(':').first;
    if (kind(a) != kind(b)) return false;
    if (kind(a) != 'hosted') return true;
    String norm(String s) => s
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('pub.dartlang.org', 'pub.dev');
    return norm(a) == norm(b);
  }

  /// Trust table under current policy.
  List<DependencyTrust> trustTable() {
    final out = <DependencyTrust>[];
    for (final dep in [
      ...workspace.pubspec.dependencies,
      ...workspace.pubspec.devDependencies,
    ]) {
      switch (dep.source) {
        case DependencySource.git:
          out.add(
            DependencyTrust(
              package: dep.name,
              sourceKind: 'git',
              trusted: policy.allowGitDependencies,
              reason: policy.allowGitDependencies ? null : 'git disallowed',
            ),
          );
        case DependencySource.path:
          final escape = dep.path != null && _escapesWorkspace(dep.path!);
          out.add(
            DependencyTrust(
              package: dep.name,
              sourceKind: 'path',
              trusted: policy.allowPathEscape || !escape,
              reason: escape ? 'path escapes workspace' : null,
            ),
          );
        case DependencySource.hosted:
          final ok = SourcePolicy.isDefaultHost(dep.hostedUrl) ||
              policy.allowExternalHostedSources;
          out.add(
            DependencyTrust(
              package: dep.name,
              sourceKind: 'hosted',
              host: dep.hostedUrl ?? 'pub.dev',
              trusted: ok,
              reason: ok ? null : 'external hosted source',
            ),
          );
        case DependencySource.sdk:
          out.add(
            DependencyTrust(
              package: dep.name,
              sourceKind: 'sdk',
              trusted: true,
            ),
          );
      }
    }
    return out;
  }
}
