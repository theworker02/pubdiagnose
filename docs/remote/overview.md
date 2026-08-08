# Remote and constrained runtimes

Runtime profiles include `full`, `headless`, `sandboxed`, `readOnly`, `remote`,
`embeddedLike`, and `ephemeral`.

```bash
pubdoctor --minimal check --offline
```

Minimal mode keeps pubspec/lockfile/graph/local diagnostics and JSON output
while disabling expensive optional systems. Remote workspaces are accessed
through transport-agnostic filesystem abstractions with soft memory budgets and
streaming listing hooks.
