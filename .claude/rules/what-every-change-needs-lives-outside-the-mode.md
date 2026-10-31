---
paths:
  - "plugins/**/skills/**"
  - "plugins/**/hooks/**"
  - "plugins/**/agents/**"
---

# What every change needs lives outside the mode

The gate, how a change is handed over and the pull request format live in the standing instructions or in a skill the agent may invoke, never only in the mode, `build:auto`.

Why: the mode is opt-in, and nothing fails in a session that never invoked it.
