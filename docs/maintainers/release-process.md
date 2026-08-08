# Release process

1. Ensure `dart analyze` and `dart test` are clean.
2. Bump `pubspec.yaml` and `lib/src/version.dart` together.
3. Update `CHANGELOG.md`.
4. Run `dart run scripts/verify.dart` when available.
5. Dogfood: `dart run bin/pubdoctor.dart check --ci`.
6. `dart pub publish --dry-run`.
7. Tag release; publish only after dry-run succeeds.

Major releases require a stability audit of CLI, JSON, diagnostics, and config
(see `docs/stability-policy.md`).
