# Commands

All commands honor `--project`, `--json`, `--verbose`, and `--no-color` where applicable.

| Command | Description |
|---------|-------------|
| `check` | Unified health report; `--ci`, `--fail-on`, `--baseline`, `--offline`, `--workers` |
| `why <pkg>` | Paths from root; `--all` |
| `graph` | Dependency tree; `--package` |
| `conflicts` | Constraint conflicts / narrow intersections |
| `overrides` | Override classification; `--test <pkg>` |
| `outdated` | Outdated with blockers; `--direct` |
| `unlock <pkg> [ver]` | Upgrade blockers |
| `sdk dart\|flutter <ver>` | SDK upgrade blockers |
| `unused` | Unused declared deps with confidence |
| `imports` | PD1301 undeclared direct imports |
| `explain <PD\|pkg>` | Diagnostic catalog or package summary |
| `workspace` | Workspace / monorepo analysis |
| `fix [PD\|pkg]` | Propose fixes; `--apply`, `--dry-run`, `--safe` |
| `baseline create\|inspect\|update\|clean` | CI baselines |
| `recover` | Recover partial writes / cache corruption |
| `cache status\|clean\|repair` | Manage `.dart_tool/pubdoctor` |
| `doctor-report` | Sanitized environment report (no secrets) |
| `inspect` | IDE/CI machine inspection (`--json`) |
| `risk [pkg]` | Evidence-driven dependency risk |
| `migrate …` | SDK/package migration plans; `status` / `resume`; `--save` |
| `migration explain` | Semantic migration knowledge for a package version range |
| `policy check\|list\|explain` | Workspace governance |
| `impact …` | Change impact / removal safety |
| `snapshot create\|list\|compare` | Project intelligence snapshots |
| `drift` | Compare current state to snapshot |
| `debug profile` | Timing / invalidation (experimental) |
| `health` | Internal PubDoctor subsystem health |
| `heal` | Plan/apply T0 self-healing; `--safe` `--apply` |
| `source check` | Project-level source diagnostics |
| `repair` | Deterministic repair; `--dry-run` `--safe` `--apply` `--certificate` |
| `upgrade simulate\|heal` | Sandbox upgrade simulation |
| `environment [snapshot\|compare]` | Runtime capability doctor; honors `--portable` |
| `reproduce check\|export` | Environment reproducibility |
| `ecosystem [package <name>]` | Pub ecosystem observatory |
| `security [lockfile]` | Supply-chain / lockfile integrity |
| `maintain` | Maintenance controller; `--audit` `--safe` `--apply` `--ci` `--repair-history` |
| `watch` | Integrity watch; `--heal-safe` `--repair-safe` `--duration` |
| `audit repair\|internal` | Repair history / architecture audit |
| `version` | Version + matrix; `--check` queries pub.dev (never auto-updates) |

Global: `--minimal` (constrained runtime), `--portable`, `--json`, `--project`.

`check` also supports `--jsonl` for streaming diagnostics.

Exit codes: `0` ok, `1` diagnostics, `2` invalid input.
