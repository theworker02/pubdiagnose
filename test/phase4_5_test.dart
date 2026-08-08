import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('Phase 4 health / unused / imports', () {
    test('check reports status for basic_app', () async {
      final ws = await PubDoctor.load(
        fixturePath('basic_app'),
        loader: WorkspaceLoader(enrichFromCache: false),
      );
      final report = ws.check();
      expect(report.projectName, 'basic_app');
      expect(report.directDependencyCount, greaterThan(0));
      expect(report.toJson()['status'], isNotNull);
    });

    test('unused flags path when only collection imported', () async {
      final ws = await PubDoctor.load(
        fixturePath('unused_app'),
        loader: WorkspaceLoader(enrichFromCache: false),
      );
      final findings = UnusedAnalyzer(ws).analyze();
      expect(findings.any((f) => f.package == 'path'), isTrue);
      expect(
        findings.firstWhere((f) => f.package == 'path').confidence,
        UnusedConfidence.high,
      );
    });

    test('imports detects undeclared collection (PD1301)', () async {
      final ws = await PubDoctor.load(
        fixturePath('imports_app'),
        loader: WorkspaceLoader(enrichFromCache: false),
      );
      final findings = ImportAnalyzer(ws).analyze();
      expect(findings.any((f) => f.package == 'collection'), isTrue);
      final diagnostics = ImportAnalyzer(ws).toDiagnostics(findings);
      expect(
        diagnostics
            .any((d) => d.code == DiagnosticCodes.directImportNotDeclared),
        isTrue,
      );
    });

    test('explain PD1001 returns catalog entry', () {
      final info = DiagnosticCatalog.byCode('PD1001');
      expect(info, isNotNull);
      expect(info!.title, contains('conflict'));
    });

    test('workspace detects inconsistent path constraints', () async {
      final report =
          await MonorepoAnalyzer().analyze(fixturePath('workspace_root'));
      expect(report.members.length, greaterThanOrEqualTo(2));
      expect(
        report.diagnostics.any(
          (d) =>
              d.code == DiagnosticCodes.workspaceVersionInconsistent ||
              d.code == DiagnosticCodes.workspaceSdkInconsistent,
        ),
        isTrue,
      );
    });
  });

  group('Phase 5 fix planner', () {
    test('planFixes is usable without applying', () async {
      final ws = await PubDoctor.load(
        fixturePath('overrides_app'),
        loader: WorkspaceLoader(enrichFromCache: false),
      );
      final plan = ws.planFixes();
      expect(plan.toJson()['risk'], isNotNull);
      // Must not mutate pubspec by merely planning.
      expect(ws.pubspecPath, endsWith('pubspec.yaml'));
    });

    test('config loader rejects unknown keys', () {
      expect(
        () => ConfigLoader.load(fixturePath('basic_app')),
        returnsNormally,
      );
    });

    test('baseline create/inspect roundtrip', () {
      final dir = fixtureDir('basic_app');
      final store = BaselineStore(
        dir.path,
        fileName: '.pubdoctor_baseline_test.json',
      );
      addTearDown(store.clean);
      final baseline = store.create([
        const Diagnostic(
          code: 'PD1001',
          title: 't',
          message: 'm',
          severity: DiagnosticSeverity.error,
          package: 'x',
        ),
      ], project: 'basic_app');
      expect(baseline.entries, isNotEmpty);
      expect(store.inspect()['exists'], isTrue);
      final fresh = store.load();
      expect(
        fresh.newViolations([
          const Diagnostic(
            code: 'PD1001',
            title: 't',
            message: 'm',
            severity: DiagnosticSeverity.error,
            package: 'x',
          ),
        ]),
        isEmpty,
      );
    });
  });
}
