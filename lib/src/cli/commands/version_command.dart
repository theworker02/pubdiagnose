import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../compatibility/matrix.dart';
import '../../version.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor version` (+ optional `--check` against pub.dev).
class VersionCommand extends PubDoctorCommand {
  /// Creates the command.
  VersionCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag(
        'check',
        help: 'Check latest version on pub.dev (never auto-updates).',
        negatable: false,
      );
  }

  @override
  String get name => 'version';

  @override
  String get description =>
      'Show PubDoctor version and compatibility matrix; optional pub.dev check.';

  @override
  Future<int> run() async {
    final payload = <String, Object?>{
      'command': 'version',
      'version': pubdoctorPackageVersion,
      'compatibility': CompatibilityMatrix.snapshot(),
    };

    if (argResults!['check'] == true) {
      try {
        final response = await http
            .get(Uri.parse('https://pub.dev/api/packages/pubdoctor'))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map && json['latest'] is Map) {
            final latest = (json['latest'] as Map)['version']?.toString();
            payload['latestOnPubDev'] = latest;
            payload['updateAvailable'] =
                latest != null && latest != pubdoctorPackageVersion;
          }
        } else {
          payload['latestOnPubDev'] = null;
          payload['checkError'] = 'HTTP ${response.statusCode}';
        }
      } on Object catch (e) {
        payload['latestOnPubDev'] = null;
        payload['checkError'] = e.toString();
      }
    }

    if (console.json) {
      console.writeJson(payload);
    } else {
      console.title('PubDoctor $pubdoctorPackageVersion');
      final compat = CompatibilityMatrix.snapshot();
      console.line('Dart SDK: ${compat['dartSdk']}');
      console.line('Platforms: ${(compat['platforms'] as List).join(', ')}');
      if (payload.containsKey('latestOnPubDev')) {
        final latest = payload['latestOnPubDev'];
        if (latest == null) {
          console.warning(
            'Could not check pub.dev: ${payload['checkError']}',
          );
        } else if (payload['updateAvailable'] == true) {
          console.warning(
            'Latest on pub.dev: $latest (you have $pubdoctorPackageVersion). '
            'Update manually — PubDoctor never auto-updates.',
          );
        } else {
          console.success('Up to date with pub.dev ($latest).');
        }
      }
    }
    return ExitCodes.ok;
  }
}
