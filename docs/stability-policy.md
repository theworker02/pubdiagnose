# Stability Policy

PubDiagnose follows [Semantic Versioning](https://semver.org/) for its **stable**
surface.

## What requires a major version bump

Breaking changes to any of the following require a new major version:

- Stable Dart library APIs exported from `package:pubdiagnose/pubdiagnose.dart`
- Stable CLI command names, required arguments, and documented exit codes
- Stable JSON fields emitted by CLI `--json` / `--jsonl` envelopes
- `pubdoctor.yaml` configuration schema keys with defined semantics
- Diagnostic identifiers (`PDxxxx`) meaning or removal

## Maturity levels

| Level | Meaning |
|-------|---------|
| `stable` | Covered by SemVer; safe for CI and library consumers |
| `experimental` | May change in minor releases; documented as such |
| `deprecated` | Scheduled for removal; prefer replacements |
| `internal` | Not part of the public contract |

See `FeatureMaturityCatalog` (`lib/src/features/feature_maturity.dart`) and
`pubdoctor inspect` → `featureMaturity`.

## Compatibility promises

- PubDiagnose does **not** replace `dart pub`’s solver.
- Offline / `--offline` modes degrade gracefully (skip network enrichment).
- Optional subsystems (plugins, Flutter inspection) failing must not abort
  core diagnostics startup.
- Automatic repair / heal never rewrites application behavior without an
  explicit, documented opt-in and transactional verify/rollback.

## Schema versions

Persisted formats under `.dart_tool/pubdoctor/` carry `schemaVersion` (see
`SchemaVersions`). Incompatible on-disk schemas trigger rebuild / heal rather
than silent misreads.
