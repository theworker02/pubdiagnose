# Supported repairs

Currently implemented deterministic classes:

- **Missing direct dependency** (PDR102 / PDS101–102): add imported package to
  `dependencies` when evidence is clear.

Preview-only / refused when ambiguous (multiple semantic choices).
Behavioral API migrations are never guessed.
