import 'package:pub_semver/pub_semver.dart';

import '../constraints/constraint_analyzer.dart';
import '../diagnostics/import_analyzer.dart';
import '../diagnostics/override_analyzer.dart';
import '../metadata/package_repository.dart';
import '../models/diagnostics.dart';
import '../models/health.dart';
import '../models/metadata.dart';
import '../models/recommendations.dart';
import '../workspace/workspace_loader.dart';
import 'compatibility_signal.dart';
import 'dependency_risk.dart';
import 'maintenance_signal.dart';
import 'risk_report.dart';
import 'risk_signal.dart';

/// Evidence-driven dependency risk intelligence.
class RiskEngine {
  /// Creates a risk engine.
  RiskEngine({
    required this.workspace,
    PackageRepository? repository,
    this.staleDays = 730,
    this.concentrationPathLimit = 32,
    this.largeWorkspace = false,
  }) : repository = repository ?? const OfflinePackageRepository();

  /// Workspace under analysis.
  final PubWorkspace workspace;

  /// Metadata source (optional enrichment).
  final PackageRepository repository;

  /// Days without a stable publish before abandoned cadence fires.
  final int staleDays;

  /// Max paths considered per package for concentration.
  final int concentrationPathLimit;

  /// Avoid expensive all-path expansion.
  final bool largeWorkspace;

  /// Analyze risk for the workspace, optionally focusing on [package].
  Future<RiskReport> analyze({String? package, bool offline = false}) async {
    final direct = {
      for (final d in workspace.pubspec.allDependencies) d.name,
    };
    final overrideNames = {
      for (final o in workspace.pubspec.dependencyOverrides) o.name,
    };

    final conflicts =
        ConstraintAnalyzer(workspace).analyze(includeNarrow: false);
    final conflictPackages = <String, List<String>>{};
    for (final c in conflicts) {
      if (c.intersection.isEmpty) {
        conflictPackages
            .putIfAbsent(c.package, () => [])
            .add(c.explanation ?? 'empty constraint intersection');
      }
    }

    final overrides = OverrideAnalyzer(workspace).analyze();
    final necessaryOverrides = {
      for (final o in overrides)
        if (o.classification == OverrideClassification.necessary) o.package: o,
    };

    List<UndeclaredImportFinding> undeclared = const [];
    try {
      undeclared = ImportAnalyzer(workspace).analyze();
    } on Object {
      // Import scan is best-effort for risk.
    }
    final transitiveImported = {
      for (final f in undeclared)
        if (!direct.contains(f.package)) f.package: f,
    };

    final candidates = <String>{};
    if (package != null) {
      candidates.add(package);
    } else {
      candidates.addAll(direct);
      candidates.addAll(overrideNames);
      candidates.addAll(conflictPackages.keys);
      candidates.addAll(transitiveImported.keys);
      if (workspace.lockfile != null) {
        for (final name in workspace.lockfile!.packages.keys) {
          if (name != workspace.pubspec.name) candidates.add(name);
        }
      }
    }

    final metaByName = <String, PackageMetadata>{};
    if (!offline && repository is! OfflinePackageRepository) {
      for (final name in candidates) {
        try {
          metaByName[name] = await repository.getPackage(name);
        } on Object {
          // Skip enrichment failures — local evidence still applies.
        }
      }
    }

    final projectSdk =
        workspace.pubspec.environment.sdk?.toString() ?? 'unknown';
    final byPackage = <String, List<RiskSignal>>{};

    void add(RiskSignal signal) {
      final pkg = signal.package;
      if (pkg == null) return;
      if (package != null && pkg != package) return;
      byPackage.putIfAbsent(pkg, () => []).add(signal);
    }

    for (final name in candidates) {
      final locked = workspace.lockfile?[name]?.version;
      final meta = metaByName[name];

      if (meta != null) {
        if (meta.isDiscontinued) {
          add(MaintenanceSignals.discontinued(
            package: name,
            replacedBy: meta.replacedBy,
          ));
          if (meta.replacedBy != null) {
            add(MaintenanceSignals.replacement(
              package: name,
              replacedBy: meta.replacedBy!,
            ));
          }
        } else if (meta.replacedBy != null) {
          add(MaintenanceSignals.replacement(
            package: name,
            replacedBy: meta.replacedBy!,
          ));
        }

        final age = meta.latestStableAge;
        if (age != null && age.inDays >= staleDays) {
          add(MaintenanceSignals.abandonedCadence(
            package: name,
            age: age,
            threshold: Duration(days: staleDays),
          ));
        }

        if (meta.preReleaseOnlyNewer ||
            (meta.latestStable == null && meta.latest != null)) {
          add(MaintenanceSignals.preReleaseOnly(
            package: name,
            latest: meta.latest!.toString(),
            latestStable: meta.latestStable?.toString(),
          ));
        }

        if (locked != null && meta.latestStable != null) {
          final lockedV = locked;
          final latest = meta.latestStable!;
          if (lockedV.major < latest.major) {
            add(CompatibilitySignals.oldMajorPin(
              package: name,
              locked: lockedV.toString(),
              latestStable: latest.toString(),
              lockedMajor: lockedV.major,
              latestMajor: latest.major,
            ));
          }
        }

        final envSdk = workspace.pubspec.environment.sdk;
        if (envSdk != null && locked != null) {
          final info = meta.versionInfo(locked);
          final pkgSdk = info?.sdkConstraint;
          if (pkgSdk != null) {
            final projectAllows = _anyVersionAllowed(envSdk);
            if (projectAllows != null && !pkgSdk.allows(projectAllows)) {
              add(CompatibilitySignals.staleSdk(
                package: name,
                packageSdk: pkgSdk.toString(),
                projectSdk: projectSdk,
              ));
            }
          }
        }
      }

      if (conflictPackages.containsKey(name)) {
        add(CompatibilitySignals.convergenceProblems(
          package: name,
          evidence: conflictPackages[name]!,
        ));
      }

      final necessary = necessaryOverrides[name];
      if (necessary != null) {
        add(CompatibilitySignals.requiresOverrides(
          package: name,
          explanation: necessary.explanation,
        ));
      }

      final undecl = transitiveImported[name];
      if (undecl != null) {
        add(
          RiskSignal(
            id: 'transitive_but_imported_directly',
            category: RiskCategory.moderate,
            confidence: RiskConfidence.high,
            title: 'Transitive package imported directly',
            message:
                '"$name" is imported in source but not declared as a direct '
                'dependency.',
            evidence: [
              for (final f in undecl.files.take(5)) 'import in $f',
              if (undecl.files.length > 5)
                '... and ${undecl.files.length - 5} more',
            ],
            package: name,
            remediation: 'Add "$name" to dependencies or stop importing it.',
          ),
        );
      }
    }

    final concentration = _concentration(
      focus: package,
      skipExpensive: largeWorkspace && package == null,
    );

    for (final c in concentration) {
      if (c.pathCount >= 8 && c.parentCount >= 3) {
        add(
          RiskSignal(
            id: 'concentration_chokepoint',
            category: RiskCategory.moderate,
            confidence: RiskConfidence.medium,
            title: 'Dependency concentration chokepoint',
            message: '"${c.package}" sits on ${c.pathCount}+ dependency paths '
                'with ${c.parentCount} parents.',
            evidence: c.evidence,
            package: c.package,
            remediation:
                'Treat upgrades of "${c.package}" carefully — many packages depend on it.',
          ),
        );
      }
    }

    final packages = <DependencyRisk>[];
    final allSignals = <RiskSignal>[];
    for (final entry in byPackage.entries) {
      final name = entry.key;
      final signals = entry.value;
      allSignals.addAll(signals);
      final locked = workspace.lockfile?[name]?.version;
      final isDirect = direct.contains(name);
      packages.add(
        DependencyRisk(
          package: name,
          signals: signals,
          worstCategory: DependencyRisk.worstOf(signals),
          isDirect: isDirect,
          isTransitive: !isDirect && workspace.lockfile?[name] != null,
          lockedVersion: locked?.toString(),
        ),
      );
    }
    packages.sort((a, b) {
      final cmp = _categoryRank(b.worstCategory)
          .compareTo(_categoryRank(a.worstCategory));
      if (cmp != 0) return cmp;
      return a.package.compareTo(b.package);
    });

    final diagnostics = _toDiagnostics(allSignals);

    return RiskReport(
      projectName: workspace.pubspec.name,
      packages: packages,
      signals: allSignals,
      concentration: concentration,
      diagnostics: diagnostics,
      focusPackage: package,
    );
  }

  List<ConcentrationPoint> _concentration({
    String? focus,
    required bool skipExpensive,
  }) {
    if (skipExpensive) return const [];
    final graph = workspace.graph;
    final targets = focus != null
        ? [focus]
        : [
            for (final n in graph.transitiveDependencies()) n.name,
          ];
    final points = <ConcentrationPoint>[];
    final pathLimit = largeWorkspace ? 8 : concentrationPathLimit;
    for (final name in targets) {
      final parents = graph.parentsOf(name);
      if (parents.length < 2) continue;
      final paths = graph.pathsTo(name, limit: pathLimit);
      if (paths.length < 3) continue;
      points.add(
        ConcentrationPoint(
          package: name,
          pathCount: paths.length,
          parentCount: parents.length,
          evidence: [
            'parents: ${parents.length}',
            'pathsSampled: ${paths.length}',
            if (paths.isNotEmpty) 'example: ${paths.first.nodes.join(' → ')}',
          ],
        ),
      );
    }
    points.sort((a, b) => b.pathCount.compareTo(a.pathCount));
    return points.take(25).toList();
  }

  List<Diagnostic> _toDiagnostics(List<RiskSignal> signals) {
    final out = <Diagnostic>[];
    for (final s in signals) {
      final code = switch (s.id) {
        'discontinued' || 'replacement' => DiagnosticCodes.riskDiscontinued,
        'abandoned_cadence' ||
        'pre_release_only' =>
          DiagnosticCodes.riskMaintenance,
        'stale_sdk' ||
        'old_major_pin' ||
        'no_stable_sdk_compatible' ||
        'blocks_sdk_migration' =>
          DiagnosticCodes.riskCompatibility,
        'requires_overrides' ||
        'convergence_problems' =>
          DiagnosticCodes.riskConvergence,
        'transitive_but_imported_directly' => DiagnosticCodes.riskImport,
        'concentration_chokepoint' => DiagnosticCodes.riskConcentration,
        _ => DiagnosticCodes.riskGeneric,
      };
      final severity = switch (s.category) {
        RiskCategory.critical => DiagnosticSeverity.critical,
        RiskCategory.high => DiagnosticSeverity.error,
        RiskCategory.moderate => DiagnosticSeverity.warning,
        RiskCategory.low || RiskCategory.unknown => DiagnosticSeverity.info,
      };
      out.add(
        Diagnostic(
          code: code,
          title: s.title,
          message: s.message,
          severity: severity,
          package: s.package,
          evidence: s.evidence,
          remediation: s.remediation,
        ),
      );
    }
    return out;
  }

  static int _categoryRank(RiskCategory c) => switch (c) {
        RiskCategory.critical => 4,
        RiskCategory.high => 3,
        RiskCategory.moderate => 2,
        RiskCategory.low => 1,
        RiskCategory.unknown => 0,
      };

  /// Pick a representative version allowed by [constraint], if any.
  static Version? _anyVersionAllowed(VersionConstraint constraint) {
    if (constraint is Version) return constraint;
    if (constraint is VersionRange) {
      final min = constraint.min;
      if (min != null) {
        if (constraint.includeMin) return min;
        return Version(min.major, min.minor, min.patch + 1);
      }
      final max = constraint.max;
      if (max != null) {
        return Version(max.major, max.minor, max.patch);
      }
    }
    return null;
  }
}

/// Offline stub repository that never hits the network.
class OfflinePackageRepository implements PackageRepository {
  /// Creates an offline repository.
  const OfflinePackageRepository();

  @override
  Future<PackageMetadata> getPackage(String name) async {
    throw StateError('Offline: metadata unavailable for $name');
  }
}
