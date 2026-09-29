# Changelog

All notable changes to the `writing` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.1.2 - 2026-09-29

- The README no longer says `unslop` loads automatically on every Markdown file: a skill's body reaches the agent only when the agent invokes it.

## 0.1.1 - 2026-09-23

- Declares no prerequisites; `unslop` no longer names the Lyngon documents.

## 0.1.0 - 2026-09-16

- Added `unslop`, vendored from poteto/noodle at commit `82d2921` with the em dashes removed from its own text, the voice section scoped to voice-bearing prose, and a neutral example in the colon pattern. The description fires on any prose writing, and `paths` loads the skill on every Markdown file.
