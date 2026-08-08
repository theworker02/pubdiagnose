# Environment reproducibility

Commands:

- `pubdoctor environment snapshot` — sanitized environment capture (no secrets)
- `pubdoctor environment compare a.json b.json` — diff with impact notes
- `pubdoctor reproduce check` — flag resolution/build drift risks
- `pubdoctor reproduce export` — portable reproduction manifest

Snapshots intentionally omit tokens, passwords, credentials, and home paths.
