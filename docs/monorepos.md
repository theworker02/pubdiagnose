# Monorepos / workspaces

```bash
pubdoctor workspace
```

Detects pub `workspace:` members or discovers `packages/*`, `apps/*`, etc. Reports:

- PD1501 inconsistent external versions
- PD1502 inconsistent SDK constraints
- PD1503 conflicting overrides
- PD1504 circular workspace deps

Does not assume Flutter.
