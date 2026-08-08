# Maintainers

PubDoctor is maintained as long-lived Dart ecosystem infrastructure.

## Responsibilities

- Keep `package:pubdoctor` public API backward compatible unless clearly defective
- Prefer diagnostics over crashes for expected failure modes
- Run `dart run scripts/verify.dart` before releases
- Update `docs/compatibility.md` when platform/SDK support changes
- Never silently discard user config during schema migrations

## Contact

- Issues: https://github.com/theworker02/pubdoctor/issues
- Security: prefer private disclosure via GitHub security advisories when available
