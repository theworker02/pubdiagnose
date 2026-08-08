# Upgrade repair

```bash
pubdoctor upgrade simulate --package foo --version 2.0.0
pubdoctor upgrade heal --package foo --version 2.0.0
```

Simulations run in an isolated temp sandbox. Repair loops have a strict
iteration limit and stop when metrics do not improve.
Behavioral migrations remain manual.
