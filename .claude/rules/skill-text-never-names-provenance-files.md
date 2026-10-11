---
paths:
  - "plugins/**/skills/**"
  - "shared/**"
---

# Skill text never names provenance files

A `SKILL.md`, a reference file and a shared document never mention a plugin's `UPSTREAM.md`, `LICENSE` or `CHANGELOG.md`; what a person needs to know about those files goes in the plugin's `README.md`.
The `devkit` plugin, whose skill writes them, is the exception.

Why: an agent in a repository that installed the plugin may open a file it sees named, and these three hold nothing it can act on there, so each mention costs context with nothing failing.
