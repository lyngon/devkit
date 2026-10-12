---
paths:
  - "plugins/**/skills/**"
  - "shared/**"
---

# Skill text never names provenance files

A `SKILL.md`, a reference file and a shared document never mention a provenance record under `catalog/vendored/`, a plugin's `LICENSE-<upstream>` or its `CHANGELOG.md`; what a person needs to know about those files goes in the plugin's `README.md`.
The `devkit` plugin, whose skill writes them, is the exception.

Why: an agent in a repository that installed the plugin may look for a file it sees named, and these three are absent there or hold nothing it can act on, so each mention costs context with nothing failing.
