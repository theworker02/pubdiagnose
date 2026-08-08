# Library API

Import `package:pubdiagnose/pubdiagnose.dart`.

Key types: `PubDoctor`, `PubWorkspace`, `DependencyGraph`, `ConstraintAnalyzer`, `HealthAnalyzer`, `FixPlanner`, `FixApplier`, `PubDoctorConfig`, `Baseline`, `DiagnosticCatalog`.

```dart
final doctor = PubDoctor();
final ws = await doctor.loadWorkspace('.');
final plan = doctor.planFixes(ws, safeOnly: true);
```
