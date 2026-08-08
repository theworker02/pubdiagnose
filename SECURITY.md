# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ |

## Reporting a vulnerability

Please report security issues privately via GitHub Security Advisories on the repository (or email maintainers if advisories are unavailable).

Do not open public issues for exploitable path traversal, YAML bomb, or SSRF concerns until a fix is available.

## Scope notes

PubDoctor reads project files and optionally contacts package repositories. It should never execute package-controlled shell commands. Fix apply mutates only `pubspec.yaml` with validation and rollback.
