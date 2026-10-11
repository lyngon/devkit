---
paths:
  - "plugins/**"
  - "shared/**"
---

# Share by symlink and dependency

Plugins share a document only through a symlink into `shared/`, and behaviour only through `dependencies` in `plugin.json`; never copy a file from one plugin into another.
Edit a shared document under `shared/`, never through its symlink inside a plugin.

Why: a copy drifts from its source with nothing failing, and an edit made through one plugin's symlink changes every plugin that links the document without showing it.
