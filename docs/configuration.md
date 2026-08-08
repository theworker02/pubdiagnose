# Configuration

Optional `pubdoctor.yaml` or `.pubdoctor.yaml` in the project root:

```yaml
ignore:
  - PD1302
  - some_package
severities:
  PD1101: warning
ci:
  fail_on: error
```

Unknown keys fail with a useful `PD0007` diagnostic. Severities: `info`, `warning`, `error`, `critical`.
