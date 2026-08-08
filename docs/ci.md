# CI

```bash
dart pub global activate pubdiagnose
pubdoctor check --ci --fail-on error
```

With baselines:

```bash
pubdoctor baseline create
pubdoctor check --ci --baseline --fail-on warning
```

Example workflow: [`.github/workflows/pubdoctor-example.yml`](../.github/workflows/pubdoctor-example.yml).

Pages deploy: [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) — enable GitHub Pages (GitHub Actions source).
