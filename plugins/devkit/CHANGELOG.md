# Changelog

All notable changes to the `devkit` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.4.1 - 2026-10-11

- `add-skill` names the four prerequisites a plugin can declare (`documents`, `workflow`, `baseline`, `structure`) and all five conditional headings. It still listed the three from before `baseline` replaced `devenv` and `workflow` was added.

## 0.4.0 - 2026-10-11

- The review checklist of `add-skill` asks that a skill uses decision records in `docs/decisions/`, and that it writes no `CLAUDE.md`, no `AGENTS.md` and no file under `.claude/rules/`.

## 0.3.0 - 2026-10-11

- `add-skill` no longer reviews a skill for agent lock-in or asks for agent-neutral wording in a new one: the devkit supports Claude Code and no other agent harness, which `INTENT.md` states as a non-goal.

## 0.2.0 - 2026-09-29

- `add-skill` commits its result as one commit on the feature branch and never pushes, instead of offering a commit message.

## 0.1.4 - 2026-09-23

- The license request template names the marketplace as a public repository and asks for permission to redistribute publicly; permission scoped to internal use is not enough.

## 0.1.3 - 2026-09-23

- Declares `baseline` instead of `devenv`.

## 0.1.2 - 2026-09-23

- `add-skill` settles a skill's prerequisites at placement time, warns when they would raise the plugin's declaration, and writes the `Prerequisites:` line and the bundle memberships for a new plugin.

## 0.1.1 - 2026-09-20

- The install reference points vendored skills at the layout in `shared/STRUCTURE.md` instead of `packages/<name>/`.
- Declares all three prerequisites; the plugin only runs in the devkit.

## 0.1.0 - 2026-09-16

- Added `add-skill`: find, vet and install a third-party skill (pinned or vendored), or design and create a new in-house skill.
