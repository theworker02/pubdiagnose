# Changelog

## 2.0.0-rc.1

### Packaging note

- Pub package published as **[`pubdiagnose`](https://pub.dev/packages/pubdiagnose)** (CLI executable remains `pubdoctor`).
- Product display name / logos: **PubDiagnose**.
- Install: `dart pub global activate pubdiagnose`

### Phases 28–35 — distributed, reproducibility, observatory, maintenance

- `check --workers N` — local distributed worker pool with result verification.
- `environment snapshot|compare`, `reproduce check|export` — sanitized env intelligence.
- `migration explain` + `migration_packs/` — versioned rules with provenance.
- `repair --certificate` — pre/post/invariant repair contracts + negative verification.
- `ecosystem` / `ecosystem package` — observatory with offline last-known cache.
- `security` / `security lockfile` + `pubdoctor.yaml` `security:` keys.
- `--minimal` + remote workspace abstractions and soft memory budgets.
- `maintain --audit|--safe|--apply|--ci|--repair-history` — bounded maintenance controller.

### Phases 14–20 — package intelligence

- `risk` — evidence-driven dependency risk (maintenance, compatibility, concentration).
- `migrate` — ordered SDK/package migration plans with save/status/resume.
- `policy` — workspace governance via `pubdoctor.yaml` policies.
- `impact` — upgrade/remove/upgrade-all change impact simulation.
- `snapshot` / `drift` — persistent project intelligence and drift detection.
- `debug profile` — incremental fingerprints and timing budgets.
- Feature maturity catalog, stability policy, maintainer docs, architecture map.

### Phases 21–27 — integrity & self-healing

- `health` / `heal` — T0 internal self-healing with journal + verify/rollback.
- `source check` — lightweight source import/part diagnostics + analyzer bridge.
- `repair` — transactional deterministic metadata repair (idempotent).
- `upgrade simulate|heal` — sandbox upgrade simulation with bounded repair loops.
- `environment` + `--portable` — runtime profiles and capability reporting.
- `watch` — incremental integrity monitoring (`--heal-safe` / `--repair-safe`).
- `audit repair|internal` — repair provenance and architecture consistency.

## 1.1.0

- Kernel architecture (`PubDoctorKernel` / `PubDoctor.open`) with shared
  execution context, capabilities, and explicit service registry.
- Platform adapters for filesystem, process, environment, terminal, and paths.
- Resilience: fault-isolated analyzer pipeline, recovery journal, cache
  status/clean/repair, `pubdoctor recover`, `pubdoctor doctor-report`.
- Compatibility matrix, schema versioning, `pubdoctor version [--check]`.
- Ecosystem: `inspect`, `check --jsonl`, controlled plugin registry, IDE docs.
- Maintenance: `scripts/verify.dart`, CI matrix, dependabot, website stub,
  ROADMAP / MAINTAINERS, architecture docs.
- CLI: check/unused/imports/explain/workspace/fix/baseline already present;
  added recover, cache, doctor-report, inspect, version.

## 1.0.0

- Initial release: dependency graph, constraint conflicts, override classification,
  outdated/unlock explanations, Dart/Flutter SDK blocker analysis, and CLI with JSON output.
