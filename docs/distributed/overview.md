# Distributed analysis

PubDoctor can fan out **independent** analysis slices across local workers
(`check --workers N`). Remote workers are supported via a versioned JSON
protocol with explicit trust scopes:

- `metadataOnly` (default minimum)
- `dependencyModel`
- `selectedFiles`
- `fullWorkspace`

The coordinator verifies every result for protocol version, input fingerprint,
worker session identity, staleness, and malformation. Stale or mismatched
results are rejected — remote output is never trusted blindly.
