# Repair overview

```bash
pubdoctor repair              # plan (default)
pubdoctor repair --dry-run
pubdoctor repair --safe --apply
pubdoctor audit repair
```

Repairs are transactional: snapshot → apply → verify → commit or rollback.
Idempotent: a second run should report no repair required when already fixed.
