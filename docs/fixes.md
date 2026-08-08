# Fixes

```bash
pubdoctor fix                 # propose
pubdoctor fix --safe
pubdoctor fix PD1101 --apply
pubdoctor fix --dry-run
```

Each change includes WHAT / WHY / EVIDENCE / EXPECTED RESULT / RISK.

`--safe` excludes potentially breaking edits. Apply is transactional: validate YAML → write → verify → rollback on failure.

Library: `workspace.planFixes()` / `FixApplier`.
