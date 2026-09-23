# Changelog

All notable changes to the `practice` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.1.0 - 2026-09-23

- Added `tdd`, `debug` and `verify`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`test-driven-development`, `systematic-debugging`, `verification-before-completion`) and rewritten to Lyngon vocabulary. The upstream eval scenarios of `systematic-debugging` were left out; `find-polluter.sh` takes the test command as an argument.
