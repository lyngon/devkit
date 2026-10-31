---
paths:
  - "docs/TODO.md"
  - "docs/seed-prompts/**"
  - "docs/plans/**"
---

# Work in progress files

`docs/TODO.md` holds only work the owner explicitly deferred, and each queued entry has a seed prompt, `docs/seed-prompts/<name>.md`, that starts a fresh session on it: self-contained, saying how to start and on which branch, and ending with "Remove this file and its `docs/TODO.md` entry in the last commit".
`docs/plans/<date>-<slug>.md` holds the design of work in progress, is committed on its branch, and is removed by the change that finishes the work.

Why: all three describe work that is not done, so one that outlives its work contradicts the tree with nothing failing.
