# Healing overview

PubDoctor can heal **its own** damaged state (cache schema, temp files, incomplete
journals) without rewriting application source.

```bash
pubdoctor health
pubdoctor heal
pubdoctor heal --safe --apply
```

`--safe` only applies T0 internal repairs with certain/high confidence.
Never use heal to rewrite app business logic.

See also: [safety-model.md](safety-model.md), [recovery.md](recovery.md).
