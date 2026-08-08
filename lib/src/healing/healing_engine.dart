import '../serialization/schema_version.dart';
import 'healing_context.dart';
import 'healing_issue.dart';
import 'healing_journal.dart';
import 'healing_policy.dart';
import 'healing_validator.dart';

export 'healing_context.dart';
export 'healing_issue.dart';
export 'healing_journal.dart';
export 'healing_policy.dart';
export 'healing_validator.dart';

/// Built-in provider for PubDoctor cache / schema / temp recovery (T0).
class CacheHealingProvider implements HealingProvider {
  /// Creates the provider.
  const CacheHealingProvider();

  @override
  String get id => 'cache';

  @override
  Future<List<HealingIssue>> detect(HealingContext context) async {
    final issues = <HealingIssue>[];
    final cache = context.cache;
    try {
      cache.ensureLayout();
    } on Object catch (e) {
      issues.add(
        HealingIssue(
          id: 'cache-layout',
          code: 'PDH201',
          title: 'Cache layout unavailable',
          message: 'Could not ensure cache layout: $e',
          tier: SafetyTier.t0Internal,
          subsystem: 'cache',
          evidence: [e.toString()],
        ),
      );
      return issues;
    }

    if (cache.needsRebuild) {
      issues.add(
        const HealingIssue(
          id: 'cache-schema',
          code: 'PDH201',
          title: 'Cache schema stale or corrupt',
          message: 'Metadata cache contains stale or missing schema entries.',
          tier: SafetyTier.t0Internal,
          subsystem: 'cache',
          evidence: ['needsRebuild: true'],
        ),
      );
    }

    final schema = cache.readSchemaVersion();
    if (schema != null && schema != SchemaVersions.cache) {
      issues.add(
        HealingIssue(
          id: 'cache-schema-mismatch',
          code: 'PDH201',
          title: 'Cache schema mismatch',
          message:
              'Cache schemaVersion=$schema expected ${SchemaVersions.cache}.',
          tier: SafetyTier.t0Internal,
          subsystem: 'cache',
          evidence: ['schemaVersion: $schema'],
        ),
      );
    }

    // Orphan / temp files under cache.
    var temps = 0;
    for (final e in cache.fs.listDirectory(cache.cacheDir)) {
      final name = cache.paths.basename(e.path);
      if (name.endsWith('.tmp') || name.endsWith('.partial')) {
        temps++;
      }
    }
    if (temps > 0) {
      issues.add(
        HealingIssue(
          id: 'cache-temps',
          code: 'PDH214',
          title: 'Incomplete temporary cache files',
          message: '$temps incomplete temporary file(s) in cache.',
          tier: SafetyTier.t0Internal,
          subsystem: 'cache',
          evidence: ['tempCount: $temps'],
        ),
      );
    }

    return issues;
  }

  @override
  Future<HealingPlan?> plan(HealingIssue issue, HealingContext context) async {
    final actions = <HealingAction>[];
    switch (issue.id) {
      case 'cache-schema':
      case 'cache-schema-mismatch':
      case 'cache-layout':
        actions.add(
          const HealingAction(
            id: 'rebuild-cache-layout',
            description: 'Rebuild PubDoctor cache layout and schema marker',
            risk: HealingRisk.low,
            confidence: HealingConfidence.certain,
            filesAffected: ['.dart_tool/pubdoctor/schema.json'],
          ),
        );
        actions.add(
          const HealingAction(
            id: 'prune-corrupt-cache',
            description: 'Remove corrupt cache objects',
            risk: HealingRisk.low,
            confidence: HealingConfidence.certain,
            filesAffected: ['.dart_tool/pubdoctor/cache/'],
          ),
        );
      case 'cache-temps':
        actions.add(
          const HealingAction(
            id: 'remove-temp-cache',
            description: 'Remove incomplete temporary cache files',
            risk: HealingRisk.low,
            confidence: HealingConfidence.certain,
            filesAffected: ['.dart_tool/pubdoctor/cache/'],
          ),
        );
      default:
        return null;
    }
    return HealingPlan(
      id: 'heal-${issue.id}',
      issues: [issue],
      actions: actions,
      summary: 'Repair internal PubDoctor cache state for ${issue.code}',
    );
  }

  @override
  Future<HealingResult> apply(HealingPlan plan, HealingContext context) async {
    final log = <String>[];
    try {
      for (final action in plan.actions) {
        switch (action.id) {
          case 'rebuild-cache-layout':
            context.cache.ensureLayout();
            // Force rewrite schema marker.
            final marker =
                context.paths.join(context.cache.rootPath, 'schema.json');
            context.fs.writeText(
              marker,
              '{\n  "schemaVersion": ${SchemaVersions.cache},\n  '
              '"healedAt": "${DateTime.now().toUtc().toIso8601String()}"\n}\n',
            );
            log.add('Rebuilt cache schema marker');
          case 'prune-corrupt-cache':
            final repair = context.cache.repair();
            log.add('Pruned ${repair['prunedCorrupt']} corrupt cache entries');
          case 'remove-temp-cache':
            var n = 0;
            for (final e
                in context.cache.fs.listDirectory(context.cache.cacheDir)) {
              final name = context.cache.paths.basename(e.path);
              if (name.endsWith('.tmp') || name.endsWith('.partial')) {
                context.cache.fs.deleteFile(e.path);
                n++;
              }
            }
            log.add('Removed $n temporary cache files');
        }
      }
      return HealingResult(
        planId: plan.id,
        applied: true,
        rolledBack: false,
        success: true,
        actions: log,
        message: 'Cache healing applied',
      );
    } on Object catch (e) {
      return HealingResult(
        planId: plan.id,
        applied: false,
        rolledBack: false,
        success: false,
        actions: log,
        message: 'Cache healing failed: $e',
      );
    }
  }
}

/// Orchestrates healing providers with journal + verify loop.
class HealingEngine {
  /// Creates an engine.
  HealingEngine({
    required this.context,
    List<HealingProvider>? providers,
  })  : providers = providers ?? const [CacheHealingProvider()],
        journal = HealingJournal(context),
        validator = HealingValidator();

  /// Context.
  final HealingContext context;

  /// Providers.
  final List<HealingProvider> providers;

  /// Journal.
  final HealingJournal journal;

  /// Validator.
  final HealingValidator validator;

  /// Health probe across subsystems.
  Future<Map<String, Object?>> healthReport() async {
    final issues = await detect();
    final bySubsystem = <String, String>{
      'kernel': 'healthy',
      'configuration': 'healthy',
      'cache': 'healthy',
      'recoveryJournal': 'healthy',
      'diagnosticRegistry': 'healthy',
      'pluginRegistry': 'healthy',
      'schemaVersions': 'healthy',
    };
    for (final i in issues) {
      final sub = i.subsystem ?? 'cache';
      bySubsystem[sub] = 'degraded';
      if (i.code == 'PDH201') bySubsystem['schemaVersions'] = 'degraded';
    }
    return {
      'schemaVersion': SchemaVersions.healing,
      'subsystems': bySubsystem,
      'issueCount': issues.length,
      'issues': [for (final i in issues) i.toJson()],
      'recoverable': issues.isNotEmpty,
    };
  }

  /// Detect all issues.
  Future<List<HealingIssue>> detect() async {
    final out = <HealingIssue>[];
    for (final p in providers) {
      try {
        out.addAll(await p.detect(context));
      } on Object {
        // Provider failure is non-fatal.
      }
    }
    return out;
  }

  /// Build a combined plan for all (or [safeOnly]) issues.
  Future<HealingPlan> plan({bool safeOnly = false}) async {
    final issues = await detect();
    final actions = <HealingAction>[];
    final covered = <HealingIssue>[];
    for (final issue in issues) {
      if (safeOnly && issue.tier != SafetyTier.t0Internal) continue;
      for (final p in providers) {
        final partial = await p.plan(issue, context);
        if (partial == null) continue;
        for (final a in partial.actions) {
          if (safeOnly && !validator.allowsSafe(a)) continue;
          actions.add(a);
        }
        covered.add(issue);
        break;
      }
    }
    // Dedupe actions by id.
    final seen = <String>{};
    final unique = <HealingAction>[];
    for (final a in actions) {
      if (seen.add(a.id)) unique.add(a);
    }
    return HealingPlan(
      id: 'heal-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      issues: covered,
      actions: unique,
      summary: unique.isEmpty
          ? 'No healing actions required'
          : '${unique.length} healing action(s) for ${covered.length} issue(s)',
    );
  }

  /// Apply plan with verify/rollback semantics for T0 (re-detect).
  Future<HealingResult> apply(
    HealingPlan plan, {
    bool dryRun = false,
  }) async {
    journal.ensureLayout();
    final before = await healthReport();
    final beforeCount = before['issueCount'] as int? ?? 0;

    journal.append({
      'phase': 'plan',
      'plan': plan.toJson(),
      'beforeHealth': before,
    });

    if (dryRun || plan.actions.isEmpty) {
      return HealingResult(
        planId: plan.id,
        applied: false,
        rolledBack: false,
        success: plan.actions.isEmpty,
        beforeHealth: before,
        afterHealth: before,
        actions: const ['dry-run / nothing to apply'],
        message: plan.summary,
      );
    }

    // Snapshot marker for rollback of schema file.
    final schemaPath =
        context.paths.join(context.cache.rootPath, 'schema.json');
    final schemaBackup = context.fs.readText(schemaPath);

    journal.append({'phase': 'apply', 'planId': plan.id});

    HealingResult? last;
    for (final p in providers) {
      // Apply full plan once via first provider that owns actions.
      last = await p.apply(plan, context);
      if (last.applied) break;
    }
    last ??= HealingResult(
      planId: plan.id,
      applied: false,
      rolledBack: false,
      success: false,
      message: 'No provider applied the plan',
    );

    final after = await healthReport();
    final afterCount = after['issueCount'] as int? ?? 0;
    final ok = last.success &&
        validator.improved(beforeIssues: beforeCount, afterIssues: afterCount);

    if (!ok && schemaBackup != null) {
      try {
        context.fs.writeText(schemaPath, schemaBackup);
        journal.append({
          'phase': 'rollback',
          'planId': plan.id,
          'reason': 'verification failed',
        });
        return HealingResult(
          planId: plan.id,
          applied: true,
          rolledBack: true,
          success: false,
          actions: [...last.actions, 'Rolled back schema marker'],
          beforeHealth: before,
          afterHealth: await healthReport(),
          message: 'Healing verification failed; rolled back.',
        );
      } on Object {
        // keep failure
      }
    }

    journal.append({
      'phase': ok ? 'commit' : 'failed',
      'planId': plan.id,
      'result': last.toJson(),
      'afterHealth': after,
    });

    return HealingResult(
      planId: plan.id,
      applied: last.applied,
      rolledBack: false,
      success: ok,
      actions: last.actions,
      beforeHealth: before,
      afterHealth: after,
      message: ok ? 'Healing committed' : last.message,
    );
  }
}
