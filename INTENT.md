# Intent

What this repository is for, for whom, and what done means.
It changes when the purpose changes, not when the plan changes.

## Product

**Lyngon devkit** is the shared foundation for software development at Lyngon: the reusable pieces a repository needs to work the Lyngon way.
Today that is a Claude Code plugin marketplace (in-house skills, vendored third-party skills, pinned third-party plugins), the shared devenv module every repository imports, and the convention documents behind both.

## For whom

- Repository: Lyngon staff who write, vet or maintain the shared pieces.
- Artifacts: Lyngon staff and their coding agents, in every Lyngon repository.

## Done means

- A new repository set up with `/repo:init` looks and behaves like every other Lyngon repository.
- Every skill and every baseline tool used at Lyngon is installed from here, never copy-pasted.
- Every third-party piece listed here was read by a named person at a recorded commit.

## Failure means

- Skills or devenv configuration drift between repositories because copying was easier than importing.
- A vendored skill or pinned plugin lands in a project without a provenance record.
- The devkit becomes a second place to maintain what a repository's own files already say.

## Non-goals

- Distributing personal or machine-level preferences. Those live in each person's global `CLAUDE.md`.
- Supporting agents other than Claude Code, until a second agent is in use at Lyngon.
- Hosting application code or anything that is not reusable across repositories.

## Horizon

Years. This is infrastructure for every Lyngon repository.
