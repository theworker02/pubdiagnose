# Architecture

```
loader → parsers → graph → constraints → metadata
       → diagnostics → recommendations → fix planner → renderers
```

| Layer | Location |
|-------|----------|
| Load | `workspace/workspace_loader.dart` |
| Parse | `pubspec/`, `lockfile/` |
| Graph | `graph/dependency_graph.dart` |
| Constraints | `constraints/` |
| Metadata | `metadata/package_repository.dart` |
| Diagnostics | `diagnostics/` |
| Remediation | `remediation/` |
| CLI | `cli/` |

Networking, analysis, and rendering stay separated. Fixes never run implicitly from read-only commands.
