# Incident response

1. Reproduce with `pubdoctor doctor-report` and `pubdoctor inspect` (sanitized).
2. Prefer `pubdoctor recover` / `pubdoctor heal --safe` for internal state.
3. Never force-apply source repairs without verification.
4. If a release regresses, yank or publish a patch; document in CHANGELOG.
5. For corrupted `.dart_tool/pubdoctor`, cache repair / heal rebuild is safe.
