import 'dart:convert';
import 'dart:io';

/// PubDoctor verification harness.
///
/// Runs format (optional), analyze, tests, docs/schema/README/workflow checks,
/// and publish dry-run. Use `--report` for a JSON health dashboard.
Future<void> main(List<String> args) async {
  final reportOnly = args.contains('--report');
  final skipPublish = args.contains('--skip-publish');
  final results = <Map<String, Object?>>[];

  Future<void> step(String name, Future<int> Function() run) async {
    stdout.writeln('→ $name');
    final sw = Stopwatch()..start();
    final code = await run();
    results.add({
      'name': name,
      'ok': code == 0,
      'exitCode': code,
      'ms': sw.elapsedMilliseconds,
    });
    stdout.writeln(
        code == 0 ? '  OK (${sw.elapsedMilliseconds}ms)' : '  FAIL ($code)');
  }

  await step('dart pub get', () async {
    final r = await Process.run('dart', ['pub', 'get']);
    return r.exitCode;
  });

  await step('dart analyze', () async {
    final r = await Process.run('dart', ['analyze']);
    if (r.stdout.toString().trim().isNotEmpty) {
      stdout.writeln(r.stdout);
    }
    if (r.stderr.toString().trim().isNotEmpty) {
      stderr.writeln(r.stderr);
    }
    return r.exitCode;
  });

  await step('dart test', () async {
    final r = await Process.run('dart', ['test']);
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    return r.exitCode;
  });

  await step('docs validation', () async {
    final required = [
      'README.md',
      'CHANGELOG.md',
      'LICENSE',
      'docs/compatibility.md',
      'docs/architecture/overview.md',
      'docs/maintenance/release-checklist.md',
      'ROADMAP.md',
      'MAINTAINERS.md',
    ];
    final missing = [
      for (final f in required)
        if (!File(f).existsSync()) f,
    ];
    if (missing.isNotEmpty) {
      stderr.writeln('Missing: ${missing.join(', ')}');
      return 1;
    }
    return 0;
  });

  await step('schema validation', () async {
    // Ensure SchemaVersions symbols resolve via a tiny import check.
    final r = await Process.run('dart', [
      'analyze',
      'lib/src/serialization/schema_version.dart',
    ]);
    return r.exitCode;
  });

  await step('README command validation', () async {
    final readme = File('README.md').readAsStringSync();
    const cmds = [
      'check',
      'why',
      'outdated',
      'doctor-report',
      'cache',
      'recover',
      'inspect',
    ];
    final missing = [
      for (final c in cmds)
        if (!readme.contains(c)) c
    ];
    if (missing.isNotEmpty) {
      stderr.writeln('README missing commands: ${missing.join(', ')}');
      return 1;
    }
    return 0;
  });

  await step('workflow validation', () async {
    final wf = File('.github/workflows/ci.yml');
    if (!wf.existsSync()) {
      stderr.writeln('Missing .github/workflows/ci.yml');
      return 1;
    }
    final text = wf.readAsStringSync();
    if (!text.contains('dart test') || !text.contains('matrix')) {
      stderr.writeln('CI workflow missing matrix/test');
      return 1;
    }
    return 0;
  });

  if (!skipPublish) {
    await step('publish dry-run', () async {
      final r = await Process.run('dart', ['pub', 'publish', '--dry-run']);
      stdout.write(r.stdout);
      stderr.write(r.stderr);
      return r.exitCode;
    });
  }

  final failed = results.where((r) => r['ok'] != true).length;
  if (reportOnly || args.contains('--report')) {
    final report = {
      'tool': 'pubdoctor-verify',
      'ok': failed == 0,
      'failed': failed,
      'steps': results,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    File('verify-report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    stdout.writeln('Wrote verify-report.json');
  }

  if (failed > 0) {
    stderr.writeln('$failed step(s) failed');
    exit(1);
  }
  stdout.writeln('All verify steps passed');
}
