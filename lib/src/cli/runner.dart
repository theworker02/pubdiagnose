import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../models/exceptions.dart';
import '../pubdoctor.dart' show PubDoctor;
import '../version.dart';
import '../workspace/workspace_loader.dart';
import 'commands/audit_command.dart';
import 'commands/baseline_command.dart';
import 'commands/cache_command.dart';
import 'commands/check_command.dart';
import 'commands/conflicts_command.dart';
import 'commands/debug_command.dart';
import 'commands/doctor_report_command.dart';
import 'commands/drift_command.dart';
import 'commands/ecosystem_command.dart';
import 'commands/environment_command.dart';
import 'commands/explain_command.dart';
import 'commands/fix_command.dart';
import 'commands/graph_command.dart';
import 'commands/health_command.dart';
import 'commands/impact_command.dart';
import 'commands/imports_command.dart';
import 'commands/inspect_command.dart';
import 'commands/maintain_command.dart';
import 'commands/migrate_command.dart';
import 'commands/migration_command.dart';
import 'commands/outdated_command.dart';
import 'commands/overrides_command.dart';
import 'commands/policy_command.dart';
import 'commands/recover_command.dart';
import 'commands/repair_command.dart';
import 'commands/reproduce_command.dart';
import 'commands/risk_command.dart';
import 'commands/sdk_command.dart';
import 'commands/security_command.dart';
import 'commands/snapshot_command.dart';
import 'commands/source_command.dart';
import 'commands/unlock_command.dart';
import 'commands/unused_command.dart';
import 'commands/upgrade_command.dart';
import 'commands/version_command.dart';
import 'commands/watch_command.dart';
import 'commands/why_command.dart';
import 'commands/workspace_command.dart';
import 'console.dart';

/// Package version reported by `--version`.
const String pubdoctorVersion = pubdoctorPackageVersion;

/// Runs the pubdoctor CLI. Returns a process exit code.
Future<int> runPubDoctor(
  List<String> args, {
  PubDoctor? doctor,
  StringSink? out,
  StringSink? err,
}) async {
  final outSink = out ?? stdout;
  final errSink = err ?? stderr;
  final runner = PubDoctorCommandRunner(
    doctor: doctor ?? PubDoctor(),
    out: outSink,
    err: errSink,
  );

  try {
    final code = await runner.run(args);
    return code;
  } on UsageException catch (e) {
    errSink.writeln(e);
    return ExitCodes.invalid;
  } on PubDoctorException catch (e) {
    errSink.writeln(e);
    return ExitCodes.invalid;
  } on FormatException catch (e) {
    errSink.writeln(e.message);
    return ExitCodes.invalid;
  }
}

/// Command runner for pubdoctor.
class PubDoctorCommandRunner extends CommandRunner<int> {
  /// Creates the command runner.
  PubDoctorCommandRunner({
    required this.doctor,
    StringSink? out,
    StringSink? err,
  })  : _out = out ?? stdout,
        _err = err ?? stderr,
        super(
          'pubdoctor',
          'PubDoctor — Diagnose your Dart dependencies.\n\n'
              'Exit codes: 0 = ok, 1 = diagnostics found, 2 = invalid input.',
        ) {
    argParser
      ..addFlag(
        'json',
        help: 'Emit machine-readable JSON.',
        negatable: false,
      )
      ..addOption(
        'project',
        abbr: 'p',
        help: 'Path to the Dart package (directory with pubspec.yaml).',
        defaultsTo: '.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Verbose output (includes stack traces on failures).',
        negatable: false,
      )
      ..addFlag(
        'color',
        help: 'Colorize text output.',
        defaultsTo: true,
      )
      ..addFlag(
        'version',
        help: 'Print pubdoctor version.',
        negatable: false,
      )
      ..addFlag(
        'portable',
        help:
            'Portable mode: prefer project-local state; avoid user-level cache.',
        negatable: false,
      )
      ..addFlag(
        'minimal',
        help: 'Minimal runtime: pubspec/lockfile/graph/local diagnostics only; '
            'disable expensive optional systems.',
        negatable: false,
      );

    addCommand(CheckCommand());
    addCommand(WhyCommand());
    addCommand(GraphCommand());
    addCommand(ConflictsCommand());
    addCommand(OverridesCommand());
    addCommand(OutdatedCommand());
    addCommand(UnlockCommand());
    addCommand(SdkCommand());
    addCommand(UnusedCommand());
    addCommand(ImportsCommand());
    addCommand(ExplainCommand());
    addCommand(WorkspaceCommand());
    addCommand(FixCommand());
    addCommand(BaselineCommand());
    addCommand(RecoverCommand());
    addCommand(CacheCommand());
    addCommand(DoctorReportCommand());
    addCommand(InspectCommand());
    addCommand(RiskCommand());
    addCommand(MigrateCommand());
    addCommand(MigrationCommand());
    addCommand(PolicyCommand());
    addCommand(ImpactCommand());
    addCommand(SnapshotCommand());
    addCommand(DriftCommand());
    addCommand(DebugCommand());
    addCommand(HealthCommand());
    addCommand(HealCommand());
    addCommand(SourceCommand());
    addCommand(RepairCommand());
    addCommand(UpgradeCommand());
    addCommand(EnvironmentCommand());
    addCommand(ReproduceCommand());
    addCommand(EcosystemCommand());
    addCommand(SecurityCommand());
    addCommand(MaintainCommand());
    addCommand(WatchCommand());
    addCommand(AuditCommand());
    addCommand(VersionCommand());
  }

  /// Shared analysis facade.
  final PubDoctor doctor;

  final StringSink _out;
  final StringSink _err;

  /// Global options from the latest parse.
  late ArgResults globalResults;

  /// Console bound to global flags.
  ConsoleWriter consoleFor(ArgResults commandResults) {
    final json = _flag(commandResults, 'json') ||
        (globalResults['json'] as bool? ?? false);
    final verbose = _flag(commandResults, 'verbose') ||
        (globalResults['verbose'] as bool? ?? false);
    final color = (globalResults['color'] as bool? ?? true) &&
        !json &&
        stdioType(stdout) == StdioType.terminal;
    return ConsoleWriter(
      json: json,
      verbose: verbose,
      color: color,
      out: _out,
      err: _err,
    );
  }

  /// Project path from global options.
  String projectPath(ArgResults commandResults) {
    return (globalResults['project'] as String?) ?? '.';
  }

  @override
  Future<int> run(Iterable<String> args) async {
    final argResults = parse(args);
    globalResults = argResults;

    if (argResults['version'] == true) {
      _out.writeln(pubdoctorVersion);
      return ExitCodes.ok;
    }

    final result = await runCommand(argResults);
    return result is int ? result : ExitCodes.ok;
  }

  bool _flag(ArgResults results, String name) {
    if (!results.options.contains(name)) return false;
    return results[name] == true;
  }
}

/// Shared base for pubdoctor commands.
abstract class PubDoctorCommand extends Command<int> {
  /// Parent runner.
  PubDoctorCommandRunner get pd => runner! as PubDoctorCommandRunner;

  /// Loads the workspace for this invocation.
  Future<PubWorkspace> loadWorkspace() {
    return pd.doctor.loadWorkspace(pd.projectPath(argResults!));
  }

  /// Console for this invocation.
  ConsoleWriter get console => pd.consoleFor(argResults!);
}
