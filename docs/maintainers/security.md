# Security

- Never log secrets from environment variables in doctor-report / inspect.
- Network access is opt-in via capabilities and disabled by `--offline`.
- Repair / heal must not download or execute untrusted code.
- Integrity fingerprints are **not** a security guarantee.
