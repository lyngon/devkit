# Changelog

All notable changes to the `review` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.1.0 - 2026-09-23

- Added `request` and `receive`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`requesting-code-review`, `receiving-code-review`) and rewritten to Lyngon vocabulary. The reviewer template takes the plan's review focus and the executor's rulings as optional inputs for the `build` plugin.
