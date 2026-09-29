# Changelog

All notable changes to the `core` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.3.0 - 2026-09-29

- Removed `conventions`, which now declares the `workflow` prerequisite: a repository that adopts the Lyngon workflow installs it next to `core`, and `core` alone may be enabled at user scope (ADR 0017).

## 0.2.0 - 2026-09-23

- Added `build`, `practice` and `review` to the bundle; all three declare at most `documents`.

## 0.1.0 - 2026-09-23

- Added the bundle with `discover`, `writing` and `conventions`.
