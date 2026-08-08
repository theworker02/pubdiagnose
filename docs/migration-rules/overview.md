# Migration rules

Semantic migration knowledge lives in `lib/src/migration_knowledge/` with optional
packs under `migration_packs/{dart_sdk,flutter,packages}/`.

```bash
pubdoctor migration explain <package> <from> <to>
```

Every rule records provenance (`pubdoctor`, `packageMaintainer`, `analyzerFix`,
`localPack`). Automated edits must cite the rule id that caused them.
