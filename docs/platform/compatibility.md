# Platform compatibility

Core PubDoctor uses Dart APIs (filesystem, process, HTTP) through adapters —
not shell scripts.

Validated environments include Windows, macOS, Linux, CI, and offline /
read-only degraded modes via capability detection (`pubdoctor environment`).
