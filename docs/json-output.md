# JSON output

Pass `--json` (global or per-command). Payloads include a `command` field and structured diagnostics with `code`, `severity`, `evidence`, and `remediation`.

CI should prefer `--json` with `--ci` for stable machine parsing.
