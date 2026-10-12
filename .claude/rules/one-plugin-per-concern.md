---
paths:
  - "plugins/**"
  - ".claude-plugin/**"
---

# One plugin per concern

A plugin is named after one concern and holds the skills for it, in-house and vendored side by side, whatever their origin.
A bundle is the one exception: it has no skills and no concern of its own, and exists so that one command installs the plugins it depends on.

Why: the plugin is what a repository installs and updates, so a plugin per author, or one plugin for everything, would make a repository install and update skills by where they came from and not by what they are for.
