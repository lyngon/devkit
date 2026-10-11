---
paths:
  - "plugins/**"
  - "shared/**"
  - "devenv/**"
---

# Shipped text never assumes this repository

What the devkit ships (`shared/`, `devenv/` and every plugin outside the `devkit` category) is written for any Lyngon repository and never assumes this repository's layout or rules; a plugin's README is the exception, because it is read here.
A rule for developing the devkit itself goes under `.claude/rules/` or `docs/conventions/`, never into what it ships.

Why: the devkit is developed under the rules it ships, so the two are easy to confuse, and a rule that leaks into a plugin binds every Lyngon repository.
