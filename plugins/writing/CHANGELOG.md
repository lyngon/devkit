# Changelog

All notable changes to the `writing` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
The upstream commit of the vendored skill is in its provenance record, `catalog/vendored/noodle.md` in the devkit.

## 0.2.1 - 2026-10-12

- The provenance of `unslop` is in the record of its upstream, `catalog/vendored/noodle.md` in the devkit, where the skill directory held an `UPSTREAM.md` and a `LICENSE`. The upstream license is `LICENSE-noodle` in the plugin's root, and the README names both.

## 0.2.0 - 2026-10-11

- `unslop` names decision records among the kinds of prose it edits, where its description and its paragraph on reference documents said ADRs.

## 0.1.2 - 2026-09-29

- The README no longer says `unslop` loads automatically on every Markdown file: a skill's body reaches the agent only when the agent invokes it.

## 0.1.1 - 2026-09-23

- Declares no prerequisites; `unslop` no longer names the Lyngon documents.

## 0.1.0 - 2026-09-16

- Added `unslop`, vendored from poteto/noodle at commit `82d2921` with the em dashes removed from its own text, the voice section scoped to voice-bearing prose, and a neutral example in the colon pattern. The description fires on any prose writing, and `paths` loads the skill on every Markdown file.
