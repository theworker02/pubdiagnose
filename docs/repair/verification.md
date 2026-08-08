# Verification

Layers (as available):

1. Syntax / YAML
2. Dart analyzer (when process allowed)
3. Dependency resolution
4. Targeted tests
5. Full tests (when required)
6. PubDoctor diagnostics
7. Before/after regression comparison

If after > before errors → automatic rollback.
