import 'package:args/command_runner.dart';

import '../../intelligence/snapshot_store.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../models/diagnostics.dart';
import '../../models/health.dart';
import '../../risk/risk_report.dart';
import '../../workspace/workspace_loader.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor snapshot create|list|compare`
class SnapshotCommand extends PubDoctorCommand {
  /// Creates the command.
  SnapshotCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addOption('label', help: 'Optional snapshot label.')
      ..addOption('from', help: 'Baseline snapshot id for compare.')
      ..addOption('to', help: 'Target snapshot id for compare.');
  }

  @override
  String get name => 'snapshot';

  @override
  String get description =>
      'Create, list, or compare project intelligence snapshots.';

  @override
  String get invocation =>
      'pubdoctor snapshot <create|list|compare> [--label] [--from] [--to]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final action = rest.isEmpty ? 'list' : rest.first.toLowerCase();

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final store = kernel.snapshotStore();
      switch (action) {
        case 'create':
          return await _create(kernel, store);
        case 'list':
          return _list(store);
        case 'compare':
          return _compare(store);
        default:
          throw UsageException('Expected create, list, or compare.', usage);
      }
    } finally {
      await kernel.close();
    }
  }

  Future<int> _create(PubDoctorKernel kernel, SnapshotStore store) async {
    final loaded = await kernel.loadWorkspace();
    if (loaded is OperationFailure<PubWorkspace>) {
      console.error(loaded.message);
      return ExitCodes.invalid;
    }
    final ws = loaded.valueOrNull!;

    RiskReport? risk;
    final riskResult = await kernel.risk(offline: true);
    if (riskResult is! OperationFailure<RiskReport>) {
      risk = riskResult.valueOrNull;
    }

    List<Diagnostic>? diagnostics;
    final check = await kernel.check(offline: true);
    if (check is! OperationFailure<HealthReport>) {
      diagnostics = check.valueOrNull?.diagnostics;
    }

    final snap = store.create(
      ws,
      label: argResults!['label'] as String?,
      risk: risk,
      diagnostics: diagnostics,
    );
    if (console.json) {
      console.writeJson({
        'command': 'snapshot',
        'action': 'create',
        ...snap.toJson(),
      });
    } else {
      console.title('SNAPSHOT CREATED');
      console.line(snap.id);
      if (snap.label != null) console.line('Label: ${snap.label}');
    }
    return ExitCodes.ok;
  }

  int _list(SnapshotStore store) {
    final snaps = store.list();
    if (console.json) {
      console.writeJson({
        'command': 'snapshot',
        'action': 'list',
        'snapshots': [for (final s in snaps) s.toJson()],
      });
    } else {
      console.title('SNAPSHOTS');
      if (snaps.isEmpty) {
        console.line('No snapshots yet. Run: pubdoctor snapshot create');
      } else {
        for (final s in snaps) {
          console.line(
            '${s.id}${s.label != null ? ' (${s.label})' : ''} '
            '${s.createdAt.toUtc().toIso8601String()}',
          );
        }
      }
    }
    return ExitCodes.ok;
  }

  int _compare(SnapshotStore store) {
    final fromId = argResults!['from'] as String?;
    final toId = argResults!['to'] as String?;
    final snaps = store.list();
    if (snaps.length < 2 && (fromId == null || toId == null)) {
      console.error('Need at least two snapshots (or --from/--to).');
      return ExitCodes.invalid;
    }
    final from = fromId != null
        ? store.get(fromId)
        : (snaps.length >= 2 ? snaps[1] : null);
    final to = toId != null ? store.get(toId) : snaps.first;
    if (from == null || to == null) {
      console.error('Could not resolve snapshots for compare.');
      return ExitCodes.invalid;
    }
    final diff = store.compare(from, to);
    if (console.json) {
      console.writeJson({
        'command': 'snapshot',
        'action': 'compare',
        ...diff.toJson(),
      });
    } else {
      console.title('SNAPSHOT COMPARE');
      console.line('${diff.fromId} → ${diff.toId}');
      if (!diff.hasDrift) {
        console.success('No drift.');
      } else {
        for (final c in diff.changes.take(40)) {
          console.line(c);
        }
      }
    }
    return diff.hasDrift ? ExitCodes.diagnostics : ExitCodes.ok;
  }
}
