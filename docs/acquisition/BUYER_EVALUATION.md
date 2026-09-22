# Buyer evaluation â€” PubDiagnose

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

```
```bash
dart pub global activate pubdiagnose
```
```yaml
dev_dependencies:
  pubdiagnose: ^2.0.0-rc.2
```
```bash
pubdoctor check
```
```bash
cd your_project
dart pub get
pubdoctor check
pubdoctor why collection
pubdoctor outdated
```
```dart
import 'package:pubdiagnose/pubdiagnose.dart';

Future<void> main() async {
  final kernel = await PubDoctor.open('.');
  try {
    final result = await kernel.check();
    result.when(
      ok: (report) => print(report.status),
      fail: (f) => print(f.message),
    );
  } finally {
    await kernel.close();
  }
}
```
```bash
dart pub get
dart analyze
dart test
dart run scripts/verify.dart --skip-publish
```
```

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*
