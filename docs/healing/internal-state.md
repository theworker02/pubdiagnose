# Internal state

Owned by PubDoctor under `.dart_tool/pubdoctor/`:

- `cache/` — metadata cache
- `recovery/` — recovery journals
- `migrations/` — saved migration plans
- `snapshots/` — project intelligence snapshots
- `healing/` — heal transactions
- `repair/` — repair history / snapshots

Application `lib/` is never modified by `heal --safe`.
