# Changelog

All notable changes to the `practice` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
The upstream commit of the vendored skills is in their provenance record, `catalog/vendored/superpowers.md` in the devkit.

## 0.1.1 - 2026-10-12

- The provenance of the three skills is one record for their upstream, `catalog/vendored/superpowers.md` in the devkit, where each skill directory held an `UPSTREAM.md` and a `LICENSE`. The upstream license is `LICENSE-superpowers` in the plugin's root, and the README names both.

## 0.1.0 - 2026-09-23

- Added `tdd`, `debug` and `verify`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`test-driven-development`, `systematic-debugging`, `verification-before-completion`) and rewritten to Lyngon vocabulary. The upstream eval scenarios of `systematic-debugging` were left out; `find-polluter.sh` takes the test command as an argument.
