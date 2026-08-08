# Architecture map

| Folder | Role |
|--------|------|
| `kernel` | Orchestration (`PubDoctorKernel`, execution context, capabilities) |
| `graph` | Dependency topology |
| `constraints` | Version constraint intersection / conflicts |
| `diagnostics` | Findings, health, unused, imports |
| `risk` | Evidence-driven dependency risk |
| `impact` | Change-effect simulation |
| `migrations` | Ordered upgrade / SDK planning |
| `policy` | Workspace governance |
| `remediation` | Safe pubspec mutation (fix) |
| `platform` | OS / FS / process / terminal adapters |
| `compatibility` | Dart/pub evolution matrix |
| `incremental` | Fingerprints / invalidation / profiling |
| `intelligence` | Project snapshots / drift |
| `healing` | Internal self-healing (T0) |
| `source` | Dart source indexing |
| `analyzer_bridge` | Analyzer API isolation |
| `repair` | Deterministic project/source repair |
| `sandbox` | Isolated upgrade simulation |
| `runtime` | Environment profiles / portable mode |
| `integrity` | Watch / continuous integrity |
| `verification` | Multi-layer verify + audit |
| `cache` | `.dart_tool/pubdoctor` state |
| `serialization` | Schema version constants |
| `features` | FeatureRegistry + maturity |
| `cli` | Command runner and renderers |
| `workspace` | Pubspec/lock loading, monorepo |
