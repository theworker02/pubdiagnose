# Release checklist

Automated by `dart run scripts/verify.dart` where possible.

## Before tagging

- [ ] `dart pub get`
- [ ] `dart analyze` clean (no errors)
- [ ] `dart test` green
- [ ] `dart run scripts/verify.dart`
- [ ] `dart pub publish --dry-run`
- [ ] CHANGELOG.md updated for the version
- [ ] `lib/src/version.dart` matches `pubspec.yaml`
- [ ] README commands match CLI (`--help`)
- [ ] Platform support matrix in `docs/compatibility.md` current
- [ ] Branding: product **PubDiagnose**, package `pubdiagnose`, CLI `pubdoctor`

## Release channels

| Channel | How |
|---------|-----|
| stable | Tagged GitHub release + `dart pub publish` |
| optional nightly | `.github/workflows/nightly.yml` extended tests |

## After publish

- [ ] Verify `pubdoctor version --check` sees the new version
- [ ] GitHub Pages / website (if present) redeployed
- [ ] Announce breaking changes using `DeprecationRegistry` entries first
