---
paths:
  - "README.md"
  - "plugins/repo/skills/init/**"
  - "plugins/repo/skills/add-package/**"
---

# README tree mirrors the init file set

The example repository tree in `README.md` shows exactly the files that `repo:init` and `repo:add-package` write, so a change to either file set changes the tree in the same commit.

Why: the tree is what a reader takes a Lyngon repository to look like, and nothing fails when it shows a file that init no longer writes.
