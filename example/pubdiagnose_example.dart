// ignore_for_file: avoid_print

import 'package:pubdiagnose/pubdiagnose.dart';

/// Minimal library example: open a project and run a health check.
Future<void> main() async {
  final kernel = await PubDoctor.open('.');
  try {
    final result = await kernel.check();
    result.when(
      ok: (report) {
        print('Status: ${report.status}');
        print('Diagnostics: ${report.diagnostics.length}');
      },
      fail: (failure) => print('Check failed: ${failure.message}'),
    );
  } finally {
    await kernel.close();
  }
}
