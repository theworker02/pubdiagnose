import 'package:pubdoctor/pubdoctor.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('detects empty intersection conflict', () async {
    final ws = await PubDoctor.load(
      fixturePath('conflict_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );

    final conflicts = ws.analyzeConstraints();
    expect(conflicts, isNotEmpty);
    final shared = conflicts.firstWhere((c) => c.package == 'shared');
    expect(shared.intersection.isEmpty, isTrue);
    expect(shared.severity, ConflictSeverity.error);
    expect(shared.minimalIncompatible.length, greaterThanOrEqualTo(2));
    expect(shared.toJson()['package'], 'shared');

    final diagnostics = ConstraintAnalyzer(ws).toDiagnostics(conflicts);
    expect(diagnostics.first.code, DiagnosticCodes.dependencyConflict);
    expect(diagnostics.first.toJson()['code'], 'PD1001');
  });

  test('classifies overrides', () async {
    final ws = await PubDoctor.load(
      fixturePath('overrides_app'),
      loader: WorkspaceLoader(enrichFromCache: false),
    );

    final overrides = ws.analyzeOverrides();
    expect(overrides, isNotEmpty);
    final leftover = overrides.firstWhere((o) => o.package == 'leftover');
    expect(
      leftover.classification,
      OverrideClassification.possiblyUnnecessary,
    );

    final shared = overrides.firstWhere((o) => o.package == 'shared');
    expect(
      shared.classification,
      anyOf(
        OverrideClassification.possiblyUnnecessary,
        OverrideClassification.necessary,
        OverrideClassification.unknown,
      ),
    );

    final diagnostics = OverrideAnalyzer(ws).toDiagnostics(overrides);
    expect(diagnostics, isNotEmpty);
  });
}
