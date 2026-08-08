# Diagnostics (maintainers)

Diagnostic codes live in `DiagnosticCodes` (`lib/src/models/diagnostics.dart`)
and human catalog entries in `DiagnosticCatalog`.

Rules:

- Never reuse a code for a different meaning.
- Prefer adding a new code over overloading an existing one.
- Catalog every public code with title, severity default, and remediation hint.
- Risk / policy / impact / drift codes: PD16xx–PD20xx.
- Healing / repair codes use PDH* / PDR* namespaces in their own modules.
