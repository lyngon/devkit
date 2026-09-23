# Changelog

All notable changes to the `discover` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.1.2 - 2026-09-23

- Declares the `documents` prerequisite. The layout examples and the shared format documents no longer assume the Lyngon structure; the core-library placement moved into conditional sections.

## 0.1.1 - 2026-09-20

- `domain-model` layout examples follow the kind-first layout: a context's `CONCEPTS.md` and ADRs live in its core library under `libs/`.

## 0.1.0 - 2026-09-15

- Added `interview`, `domain-model` and `approach`, vendored from mattpocock/skills 1.2.3 at commit `3cca18b` with Lyngon vocabulary (`CONCEPTS.md`, `packages/`).
