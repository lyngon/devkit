---
paths:
  - "plugins/**"
  - "shared/**"
---

# Every plugin change is versioned

A commit with a user-visible change to a plugin bumps the `version` in that plugin's `plugin.json` by the commit's own semver level and adds an entry to its `CHANGELOG.md`, in the same commit.
A change to a document under `shared/` is a change to every plugin that links it.

Why: Claude Code updates an installed plugin only when its version changes, and the changelog is where a repository learns what an update does to its agents.
