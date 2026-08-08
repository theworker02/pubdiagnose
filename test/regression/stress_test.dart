import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('kernel check on conflict fixture stays bounded', () async {
    final kernel = await PubDoctor.open(
      fixturePath('conflict_app'),
      options: const PubDoctorOptions(offline: true, enrichFromCache: false),
    );
    try {
      final sw = Stopwatch()..start();
      final result = await kernel.check(offline: true);
      expect(sw.elapsedMilliseconds, lessThan(15000));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.conflictCount, greaterThan(0));
    } finally {
      await kernel.close();
    }
  });

  test('cache status/repair are idempotent', () async {
    final kernel = await PubDoctor.open(
      fixturePath('basic_app'),
      options: const PubDoctorOptions(offline: true, enrichFromCache: false),
    );
    try {
      final a = kernel.cacheCommand('status');
      final b = kernel.cacheCommand('repair');
      final c = kernel.cacheCommand('status');
      expect(a.isOk && b.isOk && c.isOk, isTrue);
    } finally {
      await kernel.close();
    }
  });
}
