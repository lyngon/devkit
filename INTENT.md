# Intent

What this repository is for, for whom, and what done means.
It changes when the purpose changes, not when the plan changes.

## Product

**Lyngon devkit** is Lyngon's Claude Code plugin marketplace: one plugin per concern, holding in-house skills and vendored third-party skills, plus pinned third-party plugins that someone at Lyngon has read.

## For whom

- Repository: Lyngon staff who write or vet plugins.
- Artifacts: Lyngon staff and their coding agents, in every Lyngon repository.

## Done means

- A new repository set up with `/repo:init` looks and behaves like every other Lyngon repository.
- Every skill used at Lyngon is installed from this marketplace, never copy-pasted.
- Every vendored skill and pinned plugin was read by a named person at a recorded commit.

## Failure means

- Skills drift between repositories because copying was easier than installing.
- A vendored skill or pinned plugin lands in a project without a provenance record.
- The marketplace is a second place to maintain what `CLAUDE.md` files already say.

## Non-goals

- Distributing organization-wide conventions. Global `CLAUDE.md` content is distributed by another mechanism.
- Supporting agents other than Claude Code, until a second agent is in use at Lyngon.
- Hosting application code or anything that is not a plugin.

## Horizon

Years. This is infrastructure for every Lyngon repository.
