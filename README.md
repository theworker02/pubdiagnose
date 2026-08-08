# PubDoctor

**Diagnose your Dart dependencies.**

Pub already resolves dependencies. PubDoctor answers the questions developers still struggle with:

- Why is this package installed?
- Which dependency introduced it?
- Why can’t this package upgrade?
- Which constraints conflict?
- Which dependency is blocking a newer Dart/Flutter SDK?
- Are `dependency_overrides` still necessary?
- What packages need to change to unlock a requested version?

Package / CLI name: `pubdoctor`.

## Installation

```bash
dart pub global activate pubdoctor
```

Or as a dev dependency:

```yaml
dev_dependencies:
  pubdoctor: ^1.0.0
```

## Quick start

```bash
cd your_project
dart pub get
pubdoctor check
pubdoctor why collection
pubdoctor outdated
```

## Commands

| Command | Purpose |
|--------|---------|
| `pubdoctor check` | Unified health report (`--ci`, `--offline`, `--baseline`, `--json`, `--jsonl`) |
| `pubdoctor why <package>` | Shortest path (+ count); `--all` for all paths |
| `pubdoctor graph` | Dependency tree; `--package <name>` to focus |
| `pubdoctor conflicts` | Conflicting / fragile constraint intersections |
| `pubdoctor overrides` | Classify overrides (never auto-edits pubspec) |
| `pubdoctor outdated` | Outdated packages **with blockers explained** |
| `pubdoctor unlock <package> [version]` | What must change to unlock a version |
| `pubdoctor sdk dart\|flutter <version>` | Packages blocking an SDK target |
| `pubdoctor unused` | Possibly unused dependencies |
| `pubdoctor imports` | Undeclared direct `package:` imports |
| `pubdoctor explain <PD####\|package>` | Explain a diagnostic code or package |
| `pubdoctor workspace` | Monorepo / workspace consistency |
| `pubdoctor fix` | Propose / apply safe remediations |
| `pubdoctor baseline` | Create / inspect / update / clean CI baseline |
| `pubdoctor recover` | Recover partial writes / cache corruption |
| `pubdoctor cache status\|clean\|repair` | Manage `.dart_tool/pubdoctor` |
| `pubdoctor doctor-report` | Sanitized environment report (no secrets) |
| `pubdoctor inspect` | Machine inspection for IDEs/CI |
| `pubdoctor version` | Version + compatibility (`--check` queries pub.dev, never auto-updates) |

### Global options

- `--project <path>` / `-p` — package directory (default `.`)
- `--json` — stable machine-readable output
- `--verbose` / `-v`
- `--no-color`
- `--help`, `--version`

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success / no issues |
| `1` | Diagnostics found |
| `2` | Invalid project or input |

## Library usage

```dart
import 'package:pubdoctor/pubdoctor.dart';

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

Legacy facade methods on `PubDoctor()` remain supported for backward compatibility.

## Platform support

Windows, macOS, and Linux are supported. Core analysis works offline without
Flutter, Git, Docker, or shell-specific tooling. See
[docs/compatibility.md](docs/compatibility.md).

## Architecture

CLI commands call `PubDoctorKernel` (shared `ExecutionContext`, capabilities,
cache, and fault-isolated analyzer pipeline). Details:
[docs/architecture/overview.md](docs/architecture/overview.md).

## Contributing

```bash
dart pub get
dart analyze
dart test
dart run scripts/verify.dart --skip-publish
```

## License

MIT
