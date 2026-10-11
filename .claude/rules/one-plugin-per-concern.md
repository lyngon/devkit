---
paths:
  - "plugins/**"
  - ".claude-plugin/**"
---

# One plugin per concern

A plugin is named after one concern and holds the skills for it, in-house and vendored side by side, whatever their origin.

Why: the plugin is the unit of installation and of versioning, so a plugin per author, or one plugin for everything, would make a repository install and update skills by where they came from and not by what they are for.
