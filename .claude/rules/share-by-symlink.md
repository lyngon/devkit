---
paths:
  - "plugins/**"
  - "shared/**"
---

# Share by symlink

Plugins share a document only through a symlink into `shared/`, never by copy, and members of `all` may name each other's skills.
Edit a shared document under `shared/`, never through its symlink inside a plugin.

Why: a copy drifts from its source with nothing failing, and an edit made through one plugin's symlink changes every plugin that links the document without showing it.
