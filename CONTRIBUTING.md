# Contributing to PubDiagnose

Thanks for contributing.

## Setup

```bash
dart pub get
dart analyze
dart test
dart run bin/pubdoctor.dart --help
```

## Guidelines

- Prefer extending existing analyzers over parallel systems.
- Add regression fixtures under `test/fixtures/` before fixing defects.
- Document only behavior that is implemented.
- Do not commit secrets.
- Keep `fix` propose-by-default; never silently rewrite pubspecs in read commands.

## PR checklist

- [ ] `dart format .`
- [ ] `dart analyze`
- [ ] `dart test`
- [ ] Docs updated if CLI/API changed
- [ ] CHANGELOG note for user-facing changes
