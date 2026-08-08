import 'package:pub_semver/pub_semver.dart';
import 'package:pubdiagnose/pubdiagnose.dart';
import 'package:test/test.dart';

import 'helpers.dart';

PackageMetadata meta(
  String name, {
  required List<String> versions,
  String? latestStable,
  Map<String, String>? sdkByVersion,
  Map<String, Map<String, String>>? depsByVersion,
}) {
  final infos = <PackageVersionInfo>[
    for (final v in versions)
      PackageVersionInfo(
        version: Version.parse(v),
        sdkConstraint: sdkByVersion == null || sdkByVersion[v] == null
            ? null
            : VersionConstraint.parse(sdkByVersion[v]!),
        dependencies: {
          for (final e in (depsByVersion?[v] ?? const {}).entries)
            e.key: VersionConstraint.parse(e.value),
        },
      ),
  ];
  return PackageMetadata(
    name: name,
    versions: infos,
    latest: Version.parse(versions.last),
    latestStable: Version.parse(latestStable ?? versions.last),
  );
}

void main() {
  test('outdated explains blockers with fake repository', () async {
    final ws = await PubDoctor.load(
      fixturePath('basic_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );

    final repo = FakePackageRepository({
      'collection': meta('collection', versions: ['1.18.0', '1.19.0']),
      'path': meta('path', versions: ['1.9.0', '1.9.1']),
      'test': meta('test', versions: ['1.25.0', '1.26.0']),
      'matcher': meta('matcher', versions: ['0.12.16', '0.12.17']),
      'stack_trace': meta('stack_trace', versions: ['1.11.1']),
    });

    final doctor = PubDoctor(repository: repo);
    final outdated = await doctor.outdated(ws, directOnly: true);
    expect(outdated, isNotEmpty);
    expect(outdated.first.toJson()['package'], isNotNull);

    final unlock = await doctor.unlock(ws, 'collection', version: '1.19.0');
    expect(unlock.desired, Version.parse('1.19.0'));
    expect(unlock.toJson()['desired'], '1.19.0');
  });

  test('sdk dart analysis uses metadata constraints', () async {
    final ws = await PubDoctor.load(
      fixturePath('basic_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );

    final repo = FakePackageRepository({
      'collection': meta(
        'collection',
        versions: ['1.18.0'],
        sdkByVersion: {'1.18.0': '>=2.0.0 <3.0.0'},
      ),
      'path': meta('path', versions: ['1.9.0']),
      'test': meta('test', versions: ['1.25.0']),
      'matcher': meta('matcher', versions: ['0.12.16']),
      'stack_trace': meta('stack_trace', versions: ['1.11.1']),
    });

    final report = await PubDoctor(repository: repo).sdkDart(ws, '3.5.0');
    expect(report.blockers.any((b) => b.package == 'collection'), isTrue);
    expect(report.toJson()['kind'], 'dart');
  });

  test('recommendation engine from outdated', () async {
    final ws = await PubDoctor.load(
      fixturePath('basic_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );
    final engine = RecommendationEngine(ws);
    final recs = engine.fromOutdated([
      OutdatedPackage(
        package: 'path',
        current: Version.parse('1.9.0'),
        latestCompatible: Version.parse('1.9.1'),
        latestStable: Version.parse('1.9.1'),
        explanation: 'Compatible upgrade available.',
      ),
    ]);
    expect(recs, isNotEmpty);
    expect(recs.first.confidence, RecommendationConfidence.high);
    expect(recs.first.toJson()['type'], 'upgradeDependency');
  });
}
