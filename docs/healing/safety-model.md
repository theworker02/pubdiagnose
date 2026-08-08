# Safety model (T0–T4)

| Tier | Meaning | Auto? |
|------|---------|-------|
| T0 | Internal PubDoctor recovery | Yes (`heal --safe`) |
| T1 | Deterministic project metadata | Only with `--safe` / `--apply` |
| T2 | Deterministic Dart source | Explicit repair permission |
| T3 | Ambiguous API migration | Preview only |
| T4 | Behavioral code changes | Never auto-guess |

Loop: observe → diagnose → plan → simulate → verify plan → snapshot → apply →
verify result → commit **or** rollback.
