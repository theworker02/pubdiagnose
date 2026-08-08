# Security / supply chain

```bash
pubdoctor security
pubdoctor security lockfile
```

`pubdoctor.yaml` security keys:

```yaml
security:
  allow_git_dependencies: false
  allow_external_hosted_sources: false
  allow_path_escape: false
```

Security-related fixes never silently rewrite package sources.
