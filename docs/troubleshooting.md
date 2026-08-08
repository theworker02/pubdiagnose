# Troubleshooting

- **Missing lockfile:** run `dart pub get` (PD0005).
- **Offline outdated/unlock:** use `--offline` on `check`, or inject `FakePackageRepository` in tests.
- **Empty graph paths:** lockfile may lack per-package dependency maps; cache enrichment helps when packages are cached.
- **fix refused:** YAML validation failed — inspect message; original file restored on rollback.
