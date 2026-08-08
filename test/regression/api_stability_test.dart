import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('PubDoctor.open returns kernel that can check offline', () async {
    final kernel = await PubDoctor.open(
      fixturePath('basic_app'),
      options: const PubDoctorOptions(offline: true, enrichFromCache: false),
    );
    try {
      final result = await kernel.check(offline: true);
      expect(result.isOk, isTrue);
      final report = result.valueOrNull!;
      expect(report.projectName, 'basic_app');
    } finally {
      await kernel.close();
    }
  });

  test('inspect JSON schemaVersion is stable', () async {
    final kernel = await PubDoctor.open(
      fixturePath('basic_app'),
      options: const PubDoctorOptions(offline: true, enrichFromCache: false),
    );
    try {
      final payload = await kernel.inspect();
      expect(payload['schemaVersion'], 1);
      expect(payload['features'], isA<List<Object?>>());
      expect(payload['capabilities'], isA<List<Object?>>());
    } finally {
      await kernel.close();
    }
  });

  test('diagnostic codes remain stable', () {
    expect(DiagnosticCodes.dependencyConflict, 'PD1001');
    expect(DiagnosticCodes.unnecessaryOverride, 'PD1101');
    expect(DiagnosticCodes.directImportNotDeclared, 'PD1301');
    expect(DiagnosticCodes.moduleFailed, 'PD0009');
    expect(DiagnosticCatalog.byCode('PD1001'), isNotNull);
  });

  test('platform detect never throws on familiar OS', () {
    final platform = PlatformService.detect();
    expect(platform.info.osName, isNotEmpty);
    expect(platform.toJson()['platform'], isNotNull);
  });

  test('OperationResult maps failures', () {
    final fail = OperationResult<int>.fail('x', code: 'PD0001');
    expect(fail.isFailure, isTrue);
    expect(fail.map((v) => v + 1).isFailure, isTrue);
  });
}
