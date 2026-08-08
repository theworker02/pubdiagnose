import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor ecosystem` / `pubdoctor ecosystem package <name>`
class EcosystemCommand extends PubDoctorCommand {
  /// Creates the command.
  EcosystemCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag('offline',
          help: 'Use last-known cache only.', negatable: false);
  }

  @override
  String get name => 'ecosystem';

  @override
  String get description =>
      'Pub ecosystem observatory (releases, deprecations, cautious forecasts).';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final offline = argResults!['offline'] == true;
    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: offline,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final loaded = await kernel.loadWorkspace();
      final ws = loaded.valueOrNull;
      final versions = <String, String>{
        if (ws?.lockfile != null)
          for (final e in ws!.lockfile!.packages.entries)
            e.key: e.value.version.toString(),
      };
      final observer = kernel.ecosystemObserver(offline: offline);

      if (rest.length >= 2 && rest.first == 'package') {
        final name = rest[1];
        final status = await observer.packageStatus(
          name,
          currentVersion: versions[name],
        );
        if (console.json) {
          console.writeJson({
            'command': 'ecosystem',
            'action': 'package',
            ...status,
          });
        } else {
          console.title('ECOSYSTEM STATUS');
          console.line(name);
          final release = status['release'] as Map<String, Object?>?;
          console.line(
            'Current project version:\n${release?['currentProjectVersion'] ?? 'unknown'}',
          );
          console.line('Latest:\n${release?['latestVersion'] ?? 'unknown'}');
          console.line('Source: ${status['source']}');
          if (status['stale'] == true) {
            console.muted('Showing last-known (stale) ecosystem metadata.');
          }
          final changes = release?['recentChanges'] as List? ?? const [];
          if (changes.isNotEmpty) {
            console.line('Recent changes:');
            for (final c in changes) {
              console.line('- $c');
            }
          }
          for (final s in (status['compatibility'] as List?) ?? const []) {
            final map =
                Map<String, Object?>.from((s as Map).cast<String, Object?>());
            if (map['likelyFutureBlocker'] == true) {
              console.warning(map['summary']?.toString() ?? '');
            }
          }
          console.line('Project impact:\n${status['projectImpact']}');
        }
        return ExitCodes.ok;
      }

      final overview = await observer.overview(projectVersions: versions);
      if (console.json) {
        console.writeJson(overview);
      } else {
        console.title('ECOSYSTEM STATUS');
        console.line('Packages surveyed: ${overview['packageCount']}');
        if (overview['offline'] == true) {
          console.muted('Offline — last-known metadata only.');
        }
      }
      return ExitCodes.ok;
    } finally {
      await kernel.close();
    }
  }
}
