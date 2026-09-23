# Changelog

All notable changes to the `devkit` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.1.2 - 2026-09-23

- `add-skill` settles a skill's prerequisites at placement time, warns when they would raise the plugin's declaration, and writes the `Prerequisites:` line and the bundle memberships for a new plugin.

## 0.1.1 - 2026-09-20

- The install reference points vendored skills at the layout in `shared/STRUCTURE.md` instead of `packages/<name>/`.
- Declares all three prerequisites; the plugin only runs in the devkit.

## 0.1.0 - 2026-09-16

- Added `add-skill`: find, vet and install a third-party skill (pinned or vendored), or design and create a new in-house skill.
