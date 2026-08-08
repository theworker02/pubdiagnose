import 'dart:convert';
import 'dart:io';

import '../../environment_snapshot/environment_diff.dart';
import '../../environment_snapshot/environment_snapshot.dart';
import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor environment` (+ snapshot|compare subcommands via rest).
class EnvironmentCommand extends PubDoctorCommand {
  /// Creates the command.
  EnvironmentCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'portable',
        help: 'Report portable-mode constraints.',
        negatable: false,
      );
  }

  @override
  String get name => 'environment';

  @override
  String get description =>
      'Detect runtime environment; snapshot and compare sanitized profiles.';

  @override
  String get invocation => 'pubdoctor environment [snapshot|compare <a> <b>]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final portable = argResults!['portable'] == true;
    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
        minimal: pd.globalResults['minimal'] == true,
      ),
    );
    try {
      if (rest.isNotEmpty && rest.first == 'snapshot') {
        final result = await kernel.environmentSnapshot();
        if (result is OperationFailure<EnvironmentSnapshot>) {
          console.error(result.message);
          return ExitCodes.invalid;
        }
        final snap = result.valueOrNull!;
        if (console.json) {
          console.writeJson({
            'command': 'environment',
            'action': 'snapshot',
            ...snap.toJson(),
          });
        } else {
          console.title('ENVIRONMENT SNAPSHOT');
          console.line('Dart ${snap.sdk.dartVersion ?? 'unknown'}');
          console.line(
            '${snap.platform.os} / ${snap.platform.architecture}',
          );
          console.line('Captured ${snap.capturedAt.toUtc().toIso8601String()}');
        }
        return ExitCodes.ok;
      }

      if (rest.isNotEmpty && rest.first == 'compare') {
        if (rest.length < 3) {
          console.error('Expected: environment compare <a.json> <b.json>');
          return ExitCodes.invalid;
        }
        final a = EnvironmentSnapshot.fromJson(
          Map<String, Object?>.from(
            (jsonDecode(File(rest[1]).readAsStringSync()) as Map)
                .cast<String, Object?>(),
          ),
        );
        final b = EnvironmentSnapshot.fromJson(
          Map<String, Object?>.from(
            (jsonDecode(File(rest[2]).readAsStringSync()) as Map)
                .cast<String, Object?>(),
          ),
        );
        final diff = EnvironmentDiff.compare(a, b);
        if (console.json) {
          console.writeJson({
            'command': 'environment',
            'action': 'compare',
            ...diff.toJson(),
          });
        } else {
          console.title('ENVIRONMENT DIFFERENCE');
          for (final e in diff.entries) {
            console.line('${e.path}:');
            console.muted('  Local: ${e.left}');
            console.muted('  Other: ${e.right}');
            if (e.impact != null) console.line('  Impact: ${e.impact}');
          }
          if (diff.isEmpty) console.success(diff.summary ?? 'No differences.');
        }
        return ExitCodes.ok;
      }

      final report = kernel.environmentReport(portable: portable);
      if (console.json) {
        console.writeJson({'command': 'environment', ...report.toJson()});
      } else {
        console.title('ENVIRONMENT');
        final caps = report.profile.capabilities;
        console.line('Operating system    ${caps['os']}');
        console.line('Architecture        ${caps['arch']}');
        console.line(
          'Flutter             ${caps['flutterAvailable'] == true ? 'available' : 'unavailable'}',
        );
        console.line(
          'Git                 ${caps['gitAvailable'] == true ? 'available' : 'unavailable'}',
        );
        console.line('Profile             ${report.profile.kind.name}');
        console.line('PubDoctor capability: ${report.capabilityLevel}');
        if (report.unavailable.isNotEmpty) {
          console.line('Unavailable:');
          for (final u in report.unavailable) {
            console.muted('  $u');
          }
        }
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
