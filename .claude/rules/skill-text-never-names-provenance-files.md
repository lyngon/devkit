---
paths:
  - "plugins/**/skills/**"
  - "shared/**"
---

# Skill text never names provenance files

A `SKILL.md`, a reference file and a shared document never mention a provenance record under `catalog/vendored/` or a plugin's `LICENSE-<upstream>`; what a person needs to know about those files goes in the plugin's `README.md`.
The `devkit` plugin, whose skill writes them, is the exception.

Why: an agent in a repository that installed the plugin may look for a file it sees named, and there the record is absent and the license holds nothing it can act on, so each mention costs context with nothing failing.
