# Architecture changes

Kernel-first rule: new subsystems register through `PubDoctorKernel`,
`FeatureRegistry`, diagnostics, serialization, CLI, tests, and docs.

Do not introduce parallel analysis engines that bypass `ExecutionContext`.

When changing public API:

1. Classify maturity (`stable` / `experimental` / …).
2. Update stability policy if SemVer impact changes.
3. Add migration notes in CHANGELOG.
