# IDE & CI integration

PubDoctor exposes stable machine formats for editors, bots, and pipelines.

## Inspect (IDE bootstrap)

```bash
pubdoctor inspect --json
```

Returns workspace summary, capabilities, features, config, and cache status
(`schemaVersion: 1`).

## Check for CI

```bash
pubdoctor check --ci --json --fail-on warning
pubdoctor check --jsonl          # stream diagnostics
pubdoctor check --offline        # no network
pubdoctor check --baseline       # only new vs .pubdoctor_baseline.json
```

Exit codes: `0` ok, `1` diagnostics, `2` invalid input.

## Programmatic API

```dart
import 'package:pubdoctor/pubdoctor.dart';

Future<void> main() async {
  final kernel = await PubDoctor.open('.');
  try {
    final result = await kernel.check(offline: true);
    result.when(
      ok: (report) => print(report.status),
      fail: (f) => print('failed: ${f.message}'),
    );
  } finally {
    await kernel.close();
  }
}
```

## GitHub Actions sketch

```yaml
- uses: dart-lang/setup-dart@v1
- run: dart pub global activate pubdoctor
- run: pubdoctor check --ci --json --fail-on error
```

See `.github/workflows/ci.yml` in this repository for the matrix used by PubDoctor itself.

## Stability

API stability tests cover JSON envelopes, CLI flags, diagnostic codes, and the
public Dart API surface under `test/regression/`.
