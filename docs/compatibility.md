# Compatibility

PubDoctor targets long-lived Dart/pub tooling. Core analysis does **not** require
Docker, Flutter, Git, Bash, PowerShell, Node, Python, or native binaries.

## Dart / Flutter

| Component | Support |
|-----------|---------|
| Dart SDK | `>=3.5.0 <4.0.0` |
| Flutter | Optional — SDK *analysis* works without a Flutter install |
| pub | Hosted pub.dev API for outdated/unlock/sdk (offline mode degrades) |

Unknown pubspec keys are tolerated and **preserved** on safe edits.

## Platforms

| OS | Status |
|----|--------|
| Windows | Supported (PowerShell, cmd, CI, non-TTY) |
| macOS | Supported |
| Linux | Supported |
| Other Unix | Graceful (treated as unix-like; no hard fail on unfamiliar OS name) |

Architectures: x64 and arm64 reviewed; core has no arch-specific native deps.

## Terminals / environments

| Environment | Behavior |
|-------------|----------|
| Interactive TTY | ANSI colors when supported; Unicode bullets |
| CI / non-TTY | ASCII-safe fallbacks; no interactive prompts |
| `NO_COLOR` / `TERM=dumb` | Colors disabled |
| Restricted FS (read-only) | Local analysis still runs; cache writes skipped |
| No network | `--offline` / capability disable; local graph still works |
| Missing HOME / PUB_CACHE | Pub-cache enrichment skipped |
| No Git / Flutter | Features that need them are optional capabilities |

## Lockfiles / schemas

- Lockfile parsers accept multiple format generations (1–3).
- Persisted formats (`baseline`, cache, recovery, JSON envelopes, config) carry
  `schemaVersion` and migrate forward without silently discarding user data.

## Version check

```bash
pubdoctor version
pubdoctor version --check   # queries pub.dev; never auto-updates
```

See also `CompatibilityMatrix.snapshot()` in `package:pubdoctor`.
