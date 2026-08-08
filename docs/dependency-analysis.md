# Dependency analysis

PubDoctor builds a graph from `pubspec.yaml` + `pubspec.lock`, optionally enriching hosted edges from the local pub cache.

- **Constraints:** intersections across dependents (`conflicts`)
- **Overrides:** necessary / unnecessary / unsafe / unknown
- **Imports:** `package:` URIs vs declared sections (PD1301)
- **Unused:** declared vs imports with confidence
- **Outdated / unlock / SDK:** repository metadata + graph blockers

Offline: local analyzers still run; network commands degrade gracefully.
