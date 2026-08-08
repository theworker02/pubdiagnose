# Architecture overview

PubDoctor is organized so every subsystem connects through a shared kernel.

```
CLI (bin/ + lib/src/cli)
        ↓
PubDoctorKernel  ←── PubDoctor.open('.')
        ↓
ExecutionContext (platform, capabilities, config, cache, repository, cancellation)
        ↓
Feature analyzers / fault-isolated AnalyzerPipeline
        ↓
Diagnostics → recommendations → remediation (optional)
```

## Ownership

| Area | Path | Responsibility |
|------|------|----------------|
| Kernel | `lib/src/kernel/` | DI, lifecycle, OperationResult, capabilities |
| Platform | `lib/src/platform/` | OS/FS/process/env/terminal adapters |
| Features | `lib/src/features/` | Feature catalog (check, why, …) |
| Diagnostics | `lib/src/diagnostics/` | Analyzers + catalog |
| Resilience | `lib/src/resilience/` | Pipeline, recovery, doctor-report |
| Cache | `lib/src/cache/` | `.dart_tool/pubdoctor` store |
| Compatibility | `lib/src/compatibility/` | SDK/pub/schema matrix |
| Plugins | `lib/src/plugins/` | Controlled extension surface |
| CLI | `lib/src/cli/` | Thin command adapters only |

## Principles

1. **No orphan modules** — features register in `FeatureRegistry`.
2. **No duplicate engines** — one graph, one diagnostic model, one fix planner.
3. **Expected problems → diagnostics**, not crashes.
4. **Explicit DI** via `ServiceRegistry` (not a service-locator dump).
5. **Public API** stays `package:pubdoctor/pubdoctor.dart`.
