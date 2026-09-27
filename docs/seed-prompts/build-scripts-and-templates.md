# Build plugin: scripts and templates

Seed prompt for a fresh Claude Code session in the devkit repository.

Fix the verified defects in the scripts and prompt templates of the `build` and `review` plugins.
They were found by three Claude Code sessions that ran `build:delegate`, `review:request` and `build:finish` in an infrastructure repository (lyngon.com, branch `feat/bootstrap`, pull request 3) on 2026-09-27.
Every claim below was checked against this repository's source on 2026-09-27.
Re-verify the line numbers, they may have moved.

This is a bounded change: no design file and no plan file.
Work on a branch named `fix/build-scripts-and-templates`.
Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form.
Bump the version of every plugin you change and add a `CHANGELOG.md` entry to each.
Run `devenv test` before handing over and report its output faithfully.

## 1. Task briefs carry the Global Constraints

`plugins/build/skills/delegate/scripts/task-brief` extracts only the `### Task N` section of the plan.
The plan header says that every task's requirements implicitly include the `### Global Constraints` section, and the delegate skill's own example (`SKILL.md`, the "User level" answer near line 444) tells an implementer that a value "is in the brief's Global Constraints".
Controllers extracted the section by hand for every dispatch.

Change: `task-brief` appends the plan's `### Global Constraints` section after the task text, under its own heading, with the same fence-aware awk extraction.
A plan without that section produces a brief without it.
Then simplify the templates: the `[GLOBAL_CONSTRAINTS]` placeholder in `references/task-reviewer-prompt.md` and the "attention lens" paragraph in `SKILL.md` point at the brief's section instead of asking the controller to paste it, keeping room for one sentence of task-specific emphasis.

## 2. The scripts print the path, and nothing else, on stdout

`task-brief` prints `wrote <path>: N lines` and `review-package` prints `wrote <path>: N commit(s), M bytes`, while `SKILL.md` (near lines 247 and 272) says both print the path.
`B=$(task-brief ...)` therefore captures the summary, and the execute skill's `scripts/task-start` works around it with a sed on the `wrote` line.

Change: both scripts print the bare path on stdout and the summary on stderr.
Remove the sed in `plugins/build/skills/execute/scripts/task-start`.

## 3. One brief and one appended report per task

`SKILL.md` near line 247 says `task-brief` writes "a uniquely named file".
It writes `tmp/build/<plan>/task-<N>-brief.md` on every call, and the report name is derived from it.
A controller that resumed a half-done task in a new session overwrote the previous session's brief and would have overwritten its report, so it renamed the files by hand.

Change: keep one brief and one report per task, and make the words match.
The brief's content is the same plan text on every call, so regenerating it is harmless; say so in `SKILL.md` and drop "uniquely named".
A report file that already exists is a prior attempt's memory: `SKILL.md` tells the controller to hand its path to the new implementer the way fix-loop rounds 4 and 5 already do, and `references/implementer-prompt.md` tells the implementer to read it first and append the new report under a dated heading, the way fix reports already append.

## 4. Review packages carry full commit messages

`review-package` lists commits with `git log --oneline`.
Two reviewers reported that they could not check the commit message rules (Conventional Commits, no co-author trailer) from the package.

Change: the Commits section lists every commit with its full message (subject and body), and the reviewer templates say that the commit messages are in the package.

## 5. Reviewers learn what changed after the inputs were written

Reviewers see the plan, the brief and the diff, but not what happened to the world since the plan was written.
The final reviewer in lyngon.com reported a Critical finding about a cloud resource the owner had already removed by hand during the session, because the inventory the plan cited predated the removal.

Change: add an optional section "State changes since the inputs were written" to `plugins/build/skills/delegate/references/task-reviewer-prompt.md`, `references/re-review-prompt.md` and `plugins/review/skills/request/references/code-reviewer.md`, next to "Rulings made during execution".
The controller fills it with the facts that superseded the plan, the spec or an inventory: manual actions, resources removed, decisions the owner took in chat.
It is left out when empty, like the other optional sections.
Add the placeholder to the placeholder lists, to the reviewer-inputs list in the delegate `SKILL.md`, and to the placeholders in `plugins/review/skills/request/SKILL.md`.

## 6. The implementer template defers to the brief on tests and commits

`references/implementer-prompt.md` lines 36 to 40 always say "Write tests" and "Commit your work: one commit per task".
Every dispatch of a task that changed a live system and committed nothing had to override both.

Change: the template says to test and commit as the brief specifies, states the default (tests as `practice:tdd` requires, one commit per task on the current branch, Conventional Commits, never on main), and says that a brief may declare that the task commits nothing.
Do not design the operational task type here; that is `docs/seed-prompts/owner-gates.md`.
This change only stops the template from contradicting a brief.

## 7. Hook evidence is per-hook output, never `devenv test`

A passing `devenv test` prints task names and times, also with `DEVENV_NO_AI_AGENT=1`; the per-hook results are not shown (verified on devenv 2.3.1).
A subagent reported the OpenTofu hooks as "Skipped" from commit-time output (prek skips a hook whose files are not staged), and disproving that took a separate run.

Change: in the implementer template's report contract, hook evidence in a devenv repository is the output of `prek run --all-files` (or `prek run --files <paths>`) inside the devenv shell, and commit-time output never counts as evidence that a hook ran.
The `build` plugin declares only `documents`, so the sentence goes under a "With devenv" heading; the rules are in `docs/conventions/prerequisites.md`.

## 8. Deferred minors and the final review outlive the workspace

`build:delegate` and `build:execute` delete the plan workspace (`tmp/build/<plan>/`) before invoking `build:finish`, and `build:finish` removes the plan file.
The executor's "Deferred minors" list then exists only in the final chat message.
In lyngon.com the final reviewer flagged this, and the owner had to ask for `docs/TODO.md` entries afterwards.

Change:

- The executors hand the workspace to `build:finish` instead of deleting it.
  `build:finish` removes it in its cleanup step on the merge and discard paths, and leaves it in place when the branch is kept or a pull request is opened, since the work has not landed.
- `build:finish`, before removing the plan (Step 2, under "With the Lyngon documents"), lists the executor's deferred minors and the ledger's `minor (deferred)` and parked lines, asks the owner which of them go to `docs/TODO.md`, writes those there with today's date, and commits them together with the plan removal.
  A branch not produced by an executor has no ledger; the step says so and moves on.
- Update the process graphs, the "Finish" section of the delegate `SKILL.md`, the execute `SKILL.md` and the rationalization tables accordingly.

## 9. `build:finish` names the landing steps after a pull request merge

After option 2 (push and open a pull request) the merge happens on the forge, and nothing tells the owner or the next session to fast-forward the local base branch.
A lyngon.com session fetched, switched back to `main` without fast-forwarding, and the next session started on a stale `main` and could not find a handover section that existed only on `origin/main`.

Change: option 2 ends with the landing steps for after the merge: switch to the base branch, `git pull --ff-only`, delete the merged local branch, remove the worktree.
Add them to the quick reference table.
The session-start warning for a branch behind its upstream is in `docs/seed-prompts/session-environment-hooks.md`, not here.

## Out of scope

- Owner gates, tasks that commit nothing, pausing and resuming a run: `docs/seed-prompts/owner-gates.md`.
- Plan self-review rules: `docs/seed-prompts/plan-and-approach-rules.md`.
- Anything in the `repo` plugin.
