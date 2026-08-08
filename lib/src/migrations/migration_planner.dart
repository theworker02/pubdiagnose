import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';

import '../cache/cache_store.dart';
import '../metadata/package_repository.dart';
import '../models/exceptions.dart';
import '../platform/filesystem_adapter.dart';
import '../platform/path_adapter.dart';
import '../recommendations/sdk_analyzer.dart';
import '../recommendations/upgrade_analyzer.dart';
import '../serialization/schema_version.dart';
import '../workspace/workspace_loader.dart';
import 'migration_plan.dart';
import 'migration_risk.dart';
import 'migration_step.dart';
import 'migration_validator.dart';

/// Plans and persists SDK / package migrations.
class MigrationPlanner {
  /// Creates a planner.
  MigrationPlanner({
    required this.workspace,
    required this.repository,
    required this.cache,
    FilesystemAdapter? fs,
    PathAdapter? paths,
  })  : _fs = fs ?? cache.fs,
        _paths = paths ?? cache.paths;

  /// Workspace.
  final PubWorkspace workspace;

  /// Metadata repository.
  final PackageRepository repository;

  /// Cache store (migrations live under its root).
  final CacheStore cache;

  final FilesystemAdapter _fs;
  final PathAdapter _paths;

  /// Migrations directory.
  String get migrationsDir => _paths.join(cache.rootPath, 'migrations');

  /// Ensure migrations layout.
  void ensureLayout() {
    cache.ensureLayout();
    _fs.createDirectory(migrationsDir);
    final marker = _paths.join(migrationsDir, 'schema.json');
    if (!_fs.fileExists(marker)) {
      _fs.writeText(
        marker,
        '${jsonEncode({
              'schemaVersion': SchemaVersions.migrations,
            })}\n',
      );
    }
  }

  /// Plan a Dart SDK migration.
  Future<MigrationPlan> planDartSdk(String version) async {
    final report = await SdkAnalyzer(
      workspace: workspace,
      repository: repository,
    ).analyzeDart(version);
    return _fromSdkReport(
      kind: MigrationTargetKind.dartSdk,
      target: version,
      blockers: [
        for (final b in report.blockers)
          (
            package: b.package,
            reason: b.explanation,
            locked: b.version.toString(),
          ),
      ],
      envNeedsUpdate:
          report.recommendations.isNotEmpty || report.blockers.isNotEmpty,
    );
  }

  /// Plan a Flutter SDK migration.
  Future<MigrationPlan> planFlutterSdk(String version) async {
    final report = await SdkAnalyzer(
      workspace: workspace,
      repository: repository,
    ).analyzeFlutter(version);
    return _fromSdkReport(
      kind: MigrationTargetKind.flutterSdk,
      target: version,
      blockers: [
        for (final b in report.blockers)
          (
            package: b.package,
            reason: b.explanation,
            locked: b.version.toString(),
          ),
      ],
      envNeedsUpdate: true,
    );
  }

  /// Plan a package upgrade migration.
  Future<MigrationPlan> planPackage(String package, String version) async {
    Version.parse(version); // validate
    final unlock = await UpgradeAnalyzer(
      workspace: workspace,
      repository: repository,
    ).unlock(package, version: version);

    final steps = <MigrationStep>[];
    var i = 0;
    for (final blocker in unlock.blockers) {
      final id = 'step-${++i}-${blocker.package}';
      steps.add(
        MigrationStep(
          id: id,
          title: 'Adjust constraint involving ${blocker.blockedBy}',
          description: 'Package "${blocker.package}" is blocked by '
              '"${blocker.blockedBy}" requiring ${blocker.constraint}.',
          package: blocker.package,
          risk: MigrationRisk(
            level: MigrationRiskLevel.moderate,
            evidence: [
              'blockedBy: ${blocker.blockedBy}',
              'constraint: ${blocker.constraint}',
            ],
            summary: 'Constraint adjustment required',
          ),
          evidence: [
            'targetPackage: $package',
            'targetVersion: $version',
          ],
        ),
      );
    }

    final upgradePrereqs = [for (final s in steps) s.id];
    steps.add(
      MigrationStep(
        id: 'step-upgrade-$package',
        title: 'Upgrade $package to $version',
        description: 'Raise the constraint / lock for "$package" to $version.',
        package: package,
        fromVersion: workspace.lockfile?[package]?.version.toString(),
        toVersion: version,
        prerequisiteIds: upgradePrereqs,
        risk: MigrationRisk(
          level: unlock.blockers.isEmpty
              ? MigrationRiskLevel.low
              : MigrationRiskLevel.high,
          evidence: [
            'blockers: ${unlock.blockers.length}',
            'desired: ${unlock.desired}',
          ],
        ),
      ),
    );

    return MigrationPlan(
      id: _newId(),
      targetKind: MigrationTargetKind.package,
      target: version,
      package: package,
      steps: steps,
      createdAt: DateTime.now().toUtc(),
    );
  }

  MigrationPlan _fromSdkReport({
    required MigrationTargetKind kind,
    required String target,
    required List<({String package, String reason, String? locked})> blockers,
    required bool envNeedsUpdate,
  }) {
    final steps = <MigrationStep>[];
    var i = 0;
    for (final b in blockers) {
      steps.add(
        MigrationStep(
          id: 'step-${++i}-${b.package}',
          title: 'Unblock ${b.package}',
          description: b.reason,
          package: b.package,
          fromVersion: b.locked,
          risk: MigrationRisk(
            level: MigrationRiskLevel.high,
            evidence: [b.reason],
            summary: 'Blocks SDK $target',
          ),
          evidence: ['targetSdk: $target'],
        ),
      );
    }

    final envPrereqs = [for (final s in steps) s.id];
    if (envNeedsUpdate || steps.isNotEmpty) {
      steps.add(
        MigrationStep(
          id: 'step-env-sdk',
          title: kind == MigrationTargetKind.dartSdk
              ? 'Update environment.sdk to allow $target'
              : 'Update environment.flutter to allow $target',
          description:
              'Adjust the root pubspec environment constraint to permit $target.',
          prerequisiteIds: envPrereqs,
          risk: MigrationRisk(
            level: blockers.isEmpty
                ? MigrationRiskLevel.low
                : MigrationRiskLevel.moderate,
            evidence: [
              'blockersRemaining: ${blockers.length}',
            ],
          ),
        ),
      );
    }

    if (blockers.isEmpty && steps.isEmpty) {
      steps.add(
        MigrationStep(
          id: 'step-verify',
          title: 'Verify SDK $target',
          description:
              'No package blockers detected. Validate with `dart pub get` '
              'after updating the environment constraint.',
          risk: const MigrationRisk(
            level: MigrationRiskLevel.low,
            evidence: ['no blockers from SdkAnalyzer'],
          ),
        ),
      );
    }

    return MigrationPlan(
      id: _newId(),
      targetKind: kind,
      target: target,
      steps: steps,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Persist plan (save).
  void save(MigrationPlan plan) {
    ensureLayout();
    final path = _paths.join(migrationsDir, '${plan.id}.json');
    final active = _paths.join(migrationsDir, 'active.json');
    final body = const JsonEncoder.withIndent('  ').convert(plan.toJson());
    _fs.writeText(path, '$body\n');
    _fs.writeText(
      active,
      '${jsonEncode({
            'schemaVersion': SchemaVersions.migrations,
            'activeId': plan.id,
          })}\n',
    );
  }

  /// List saved plans.
  List<MigrationPlan> list() {
    ensureLayout();
    final plans = <MigrationPlan>[];
    for (final entity in _fs.listDirectory(migrationsDir)) {
      final name = _paths.basename(entity.path);
      if (!name.endsWith('.json') ||
          name == 'schema.json' ||
          name == 'active.json') {
        continue;
      }
      final raw = _fs.readText(entity.path);
      if (raw == null) continue;
      try {
        plans.add(
          MigrationPlan.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          ),
        );
      } on Object {
        continue;
      }
    }
    plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return plans;
  }

  /// Load active plan, if any.
  MigrationPlan? active() {
    ensureLayout();
    final raw = _fs.readText(_paths.join(migrationsDir, 'active.json'));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final id = json['activeId']?.toString();
      if (id == null) return null;
      final planRaw = _fs.readText(_paths.join(migrationsDir, '$id.json'));
      if (planRaw == null) return null;
      return MigrationPlan.fromJson(
        Map<String, Object?>.from(jsonDecode(planRaw) as Map),
      );
    } on Object {
      return null;
    }
  }

  /// Status of the active migration.
  Map<String, Object?> status() {
    final plan = active();
    if (plan == null) {
      return {
        'schemaVersion': SchemaVersions.migrations,
        'active': false,
      };
    }
    final validation = MigrationValidator().validate(plan);
    return {
      'schemaVersion': SchemaVersions.migrations,
      'active': true,
      'plan': plan.toJson(),
      'validation': validation.toJson(),
    };
  }

  /// Resume: mark next ready steps and re-validate (does not mutate pubspec).
  MigrationPlan resume() {
    final plan = active();
    if (plan == null) {
      throw InvalidProjectException(
        'No active migration to resume. Run `pubdoctor migrate ... --save`.',
        code: 'PD0007',
      );
    }
    final validation = MigrationValidator().validate(plan);
    final updated = <MigrationStep>[];
    for (final step in plan.steps) {
      if (validation.readyStepIds.contains(step.id) &&
          step.status == MigrationStepStatus.pending) {
        updated.add(step.copyWith(status: MigrationStepStatus.ready));
      } else {
        updated.add(step);
      }
    }
    final next = plan.copyWith(
      steps: updated,
      updatedAt: DateTime.now().toUtc(),
    );
    save(next);
    return next;
  }

  /// Dry-validate a plan without mutating the project.
  MigrationValidationResult validate(MigrationPlan plan) =>
      MigrationValidator().validate(plan);

  String _newId() {
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return 'mig-$ts';
  }
}
