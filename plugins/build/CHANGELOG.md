# Changelog

All notable changes to the `build` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.7.0 - 2026-09-30

- `delegate` gains `scripts/pin`, which prints a file's sha256 in the form an owner gate records (`sha256:<hex> <file>`) and checks a file against a recorded pin with `--check`, using `sha256sum` or `shasum`. The build scripts have fixture tests in `tests/scripts.sh`, which also prove that `review-package` accepts a range holding only an empty record commit.

## 0.6.0 - 2026-09-29

- `finish` asks once before the push unless the user's standing instructions cover pushing and opening a pull request; under the Lyngon workflow, `conventions:engineering`'s do, and it pushes without asking as before. `WORKFLOW.md` names `conventions:engineering` only under a "With the Lyngon workflow" heading. The README lists the deferred-findings question after the pull request, where `finish` asks it. `plan`, `execute` and `delegate` say the push is left to `finish` instead of saying it is never a stop.

## 0.5.0 - 2026-09-29

- `plan`, `execute` and `delegate` name the pull request as the user's second gate, and the executors no longer stop for pushing the feature branch or opening its pull request. `WORKFLOW.md` puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request. The plugin's description ends at an open pull request instead of an integrated branch.

## 0.4.0 - 2026-09-29

- `finish` pushes the branch and opens the pull request without asking instead of presenting a menu, and merges locally or keeps the branch only on request. The description carries what changed, decisions for the user, the executor's rulings and deferred minors with a link to the plan, unfixed findings and the verification. An existing pull request gets its description updated; without a remote the branch is kept, and without a forge CLI the creation link is handed over. Deferred findings go into the description, and the question which of them go to `docs/TODO.md` comes after the pull request is open.

## 0.3.0 - 2026-09-29

- `plan` requires every check the plan mandates (a script, a command with an expected output, a condition a task verifies before it proceeds) to be shown failing when its property does not hold and passing when it does. A check without that control is a placeholder, and self-review looks for it.
- `plan` self-review checks every block of prose the plan dictates (ADR text, README steps, `CLAUDE.md` lines, `CONCEPTS.md` entries) against the existing ADRs, the gates and rules in `CLAUDE.md`, and the findings recorded earlier in the design and plan.
- `plan` writes a command a person runs by hand in POSIX sh or through `bash -c`, and points at `conventions:shell` for the rules of scripts.

## 0.2.0 - 2026-09-29

- Task briefs carry the plan's Global Constraints section after the task text. The task reviewer reads them in the brief; the controller adds at most one sentence of emphasis instead of pasting them.
- `task-brief` and `review-package` print only the file path on stdout and their summary on stderr, so `B=$(task-brief ...)` captures the path.
- One brief and one report per task. A report file left by an earlier attempt is handed to the new implementer, who reads it first and appends under a dated heading.
- Review packages list every commit with its full message, so reviewers can check the commit rules.
- Every reviewer gets the state changes since the plan was written, ledgered as `State:` lines, in an optional section.
- The implementer template tests and commits as the brief says, with the previous behaviour as the default, and a brief may declare that a task commits nothing. Hook evidence is the output of an explicit hook run, never commit-time output; with devenv, `prek run --all-files`.
- `delegate` and `execute` hand the plan workspace to `finish` instead of deleting it. `finish` offers the deferred minors and parked findings for `docs/TODO.md` before it removes the plan, and removes the workspace when the work lands.
- `finish` ends a pull request with the landing steps for after the forge merges it: switch to the base branch, `git pull --ff-only`, remove the worktree and delete the local branch.

## 0.1.0 - 2026-09-23

- Added `plan`, `execute`, `delegate` and `finish`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`) and rewritten to Lyngon vocabulary: plans in `docs/plans/` on the branch, the ledger in `tmp/build/`, one commit per task on a feature branch, review at the plan and the branch, no package installs, and the worktree skill folded into the executors' setup.
- `plan` links the shared `WORKFLOW.md`, which lays out the flow between the discover, build, practice and review skills and the user's gates.
