# Compatibility (maintainers)

Compatibility matrix data lives under `lib/src/compatibility/`.

When Dart or Flutter ships a breaking SDK constraint change:

1. Update matrix entries with evidence (release notes / pub constraints).
2. Add regression fixtures where practical.
3. Do not auto-update the CLI binary from the network.
