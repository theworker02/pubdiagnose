// ignore_for_file: avoid_print

import 'package:pub_semver/pub_semver.dart';
import 'package:pubdoctor/pubdoctor.dart';

/// Example: load a workspace and explain why a package is present.
Future<void> main() async {
  final workspace = await PubDoctor.load('.');

  print('Project: ${workspace.pubspec.name}');
  print('Direct dependencies:');
  for (final node in workspace.graph.directDependencies()) {
    print('  - ${node.name}'
        '${node.version != null ? ' @ ${node.version}' : ''}');
  }

  final conflicts = workspace.analyzeConstraints();
  if (conflicts.isEmpty) {
    print('No constraint conflicts detected.');
  } else {
    print('Conflicts:');
    for (final conflict in conflicts) {
      print('  ${conflict.package}: ${conflict.explanation}');
    }
  }

  // Optional: outdated analysis with an injectable repository.
  final doctor = PubDoctor(
    repository: FakePackageRepository({
      // In real usage, omit this to use pub.dev.
      'path': PackageMetadata(
        name: 'path',
        versions: [
          PackageVersionInfo(version: Version.parse('1.9.0')),
        ],
        latest: Version.parse('1.9.0'),
        latestStable: Version.parse('1.9.0'),
      ),
    }),
  );
  print('Doctor ready: ${doctor.repository.runtimeType}');
}
