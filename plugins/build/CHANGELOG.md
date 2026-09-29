# Changelog

All notable changes to the `build` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.2.0 - 2026-09-29

- Task briefs carry the plan's Global Constraints section after the task text. The task reviewer reads them in the brief; the controller adds at most one sentence of emphasis instead of pasting them.
- `task-brief` and `review-package` print only the file path on stdout and their summary on stderr, so `B=$(task-brief ...)` captures the path.
- One brief and one report per task. A report file left by an earlier attempt is handed to the new implementer, who reads it first and appends under a dated heading.
- Review packages list every commit with its full message, so reviewers can check the commit rules.

## 0.1.0 - 2026-09-23

- Added `plan`, `execute`, `delegate` and `finish`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`) and rewritten to Lyngon vocabulary: plans in `docs/plans/` on the branch, the ledger in `tmp/build/`, one commit per task on a feature branch, review at the plan and the branch, no package installs, and the worktree skill folded into the executors' setup.
- `plan` links the shared `WORKFLOW.md`, which lays out the flow between the discover, build, practice and review skills and the user's gates.
