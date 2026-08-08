# Recovery

Interrupted operations leave journals under `.dart_tool/pubdoctor/`.

```bash
pubdoctor recover
pubdoctor heal --safe --apply
pubdoctor cache repair
```

Healing journals: `.dart_tool/pubdoctor/healing/journal.jsonl`.
