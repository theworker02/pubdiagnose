# Maintenance controller

```bash
pubdoctor maintain --audit
pubdoctor maintain --safe
pubdoctor maintain --apply
pubdoctor maintain --ci
pubdoctor maintain --repair-history
```

Actions are priority-ordered (internal corruption → security → resolution →
source → tests → SDK → upgrades → cleanup). Cycles enforce action/time/file/line
limits. When a prior PubDoctor transaction caused a regression and rollback is
unsafe, a compensating transaction is proposed instead of blind restore.

Automatic maintenance never invents app behavior, deletes sources, weakens
security policy, suppresses diagnostics, or edits tests merely to pass.
