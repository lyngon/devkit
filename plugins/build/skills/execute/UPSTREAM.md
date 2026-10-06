# execute

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/executing-plans`
- **Upstream name**: `executing-plans`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The inline executor: one context does every task of a plan, writing the tests and the code the plan leaves to its implementer, with a ledger that survives compaction so a resumed session never redoes a finished task, and one fresh reviewer at the end.
It is the cheap execution mode; `build:delegate` is the thorough one, and both share a workspace so a plan can switch executor mid-flight.

## Local patches

- Renamed `executing-plans` to `execute`.
- Description rewritten to say what the skill does and when to use it.
- Skill references remapped: `superpowers:writing-plans` to `build:plan`, `superpowers:subagent-driven-development` to `build:delegate`, `superpowers:test-driven-development` to `practice:tdd`, `superpowers:systematic-debugging` to `practice:debug`, `superpowers:verification-before-completion` to `practice:verify`, `superpowers:requesting-code-review` to `review:request`, `superpowers:finishing-a-development-branch` to `build:finish`; the pointer to `../using-superpowers/references/` dropped.
- Workspace moved from `<repo-root>/.superpowers/sdd/<plan-basename>/` to `<repo-root>/tmp/build/<plan-slug>/`, resolved by `../delegate/scripts/workspace` (upstream `../subagent-driven-development/scripts/sdd-workspace`). Ledger first line changed from the upstream `# SDD ledger` header (which carried an em dash) to `# build ledger: plan <path>`. Added that `tmp/` may be emptied at any time, recover from `git log`.
- Setup: the worktree paragraph pointing at `superpowers:using-git-worktrees` replaced by an `### Isolated workspace` section (ask once whether to use a worktree, prefer the harness's native tool, fall back to `git worktree add .worktrees/<branch>` with `.worktrees/` git-ignored, never install packages, never start on main without consent, the plan is already committed on the branch) with a `#### With devenv` subsection (entering the worktree and running `devenv shell` gives the same environment).
- Spec pointer: "If the plan names a Spec" became "the `## Design` section of the same file, otherwise the external spec the plan header points at".
- Stop conditions: the four upstream stops plus a fifth, a check or hook that could only be passed by disabling, skipping or weakening it, with the rule never to do so. "Only the four stops" became "only the five stops"; one rationalization row added for skipping a failing hook.
- Continuous execution names the user's two review gates (the plan before, the finished branch after).
- Commit rule made explicit in "Work the steps": one commit per task on the feature branch, Conventional Commits, one concern per commit, never on main.
- Final review: the cross-plugin file reference `[code-reviewer.md](../requesting-code-review/code-reviewer.md)` replaced by invoking `review:request`, which holds the template; inputs listed as the review package path, the plan and its Design section, the Review Focus verbatim and the ledger's `Ruling:` lines. Without a subagent tool: invoke `review:request` and apply its brief yourself, ledger `Final review: self-review (no subagent tool)`.
- Ledger line formats use semicolons where upstream used em dashes: `Ruling: <what>; <why>; <cost>`, `Final: fixed <finding>; <test> RED→GREEN, suite <N>/<N>`.
- Finish: added that the user reads the finished branch starting from "Rulings I made" and "Deferred minors"; ends by calling the Skill tool for `build:finish`.
- Scripts `task-start` and `task-done`: now call `../../delegate/scripts/task-brief` and `../../delegate/scripts/workspace` (upstream `../../subagent-driven-development/scripts/{task-brief,sdd-workspace}`), through `bash` rather than direct exec as the delegate scripts do; the ledger header changed as above; comments reworded without dashes. Exec bits kept.
- The process graph: `systematic-debugging` node renamed to `practice:debug`, the final node to "Invoke build:finish", the review node names `review:request`, "spec" became "design" in the setup node; edge labels lose their dashes.
- Example workflow: paths rewritten to `docs/plans/2026-09-23-recovery.md`, workspace to `../delegate/scripts/workspace`, the opening announcement dropped, "typo" became "misspells", `npm test` kept as an example with a sentence saying so, the closing line invokes `build:finish`.
- "Announce at start" line dropped. "your human partner" and "your partner" replaced by "the user" throughout. Rationalization table: "Only the four stops" and "your partner decides" reworded.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; bold labels end in a full stop instead of a colon; the sub-skill callouts say "call the Skill tool for".
- `task-start` takes the bare path that `task-brief` now prints; upstream parsed the `wrote <path>: N lines` line with sed.
- The brief carries the plan's Global Constraints, and "Take the task" says so.
- Final review: the reviewer also gets the ledger's `State:` lines (facts that superseded the plan, the spec or an inventory), which the executor ledgers as `State: <fact>` when it learns them.
- Finish: the workspace is handed to `build:finish` instead of deleted (upstream deleted it here), so the ledger's deferred minors reach `build:finish`; the graph node, the Finish section and the example say so, and a rationalization row was added. "The only place" the rulings reach the user became "where".
- The second gate is the pull request that `build:finish` opens, and the final message's two lists go into its description. The stop list's side effects are the ones the user's standing instructions leave to them (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish); pushing the feature branch and opening its pull request are left to `build:finish`, which asks before the push unless the user's standing instructions cover it.
- Owner gates, which are not upstream: continuous execution names the review gates and the owner gates; the five stops run the protocol in `../delegate/references/owner-gates.md`; the process graph branches on a gated task; `task-start` passes `--part pre-gate|post-gate` to `task-brief`; setup restores a paused run's ledger; an `## Owner gates` section says how the inline executor differs (it runs both parts, dispatches the evidence reviewer, and records the completion with `task-done`); the final message lists the owner gates; three rationalization rows; the stop list names the owner gates the plan declares beside the five stops.
- Owner gates: `Task N post-gate: started` is ledgered before any post-gate step runs.
- `workspace`, `execution-status restore` and `review-package` are named as `<this skill's directory>/../delegate/scripts/...` and run from the repository root, where "from this skill's directory" was read as changing into it.
- `task-done` records a passing test command that prints nothing, with `(no output)` as the last line, where upstream exited 1 under `pipefail` and recorded nothing.
- `## Owner gates`: the evidence review passes the task's ledger lines and the hash of its record commit in place of the report files, which the inline executor does not write.
- Setup follows Resuming in `../delegate/references/owner-gates.md` for a plan that declares owner gates or holds an Execution status, whether or not the run paused, where it restored only a paused run's ledger; recovering a lost workspace points gated tasks at the same section; the resume rule and its gated-task exception are one sentence; `PLAN_FILE` is the plan's path relative to the repository root in the ledger's identity line and every script call; the rationalization row says a run-time approval lapses when the session that received it ends before the post-gate part starts.
- `## Owner gates`: the evidence review's findings are screened before any fix, and one whose fix needs another live action becomes an unforeseen gate.
- `## Owner gates`: the post-gate part of an unforeseen gate starts with `task-start PLAN_FILE N` without `--part`, at the step after the stop.
- Finish: the "Owner gates" list holds one entry per gate, and the paragraph says `build:finish` puts three lists in the pull request description and reads the owner gates from their record commits.
- Owner gates, which are not upstream: the record commit body starts with the line `Owner gate: <id>`.
- Owner gates, which are not upstream: an unforeseen gate's post-gate part keeps the task's original BASE for the evidence-review package and `task-done`; the lapsed-approval row names the unforeseen-gate exception.
- Owner gates, which are not upstream: after `task-done` records a gated task's completion, the task's temporary files are removed, as the protocol's step 8 says.
- Final review: a final finding that conflicts with the plan or the owner gate protocol, or that needs no change to the branch, is ruled on and ledgered; the fix pass takes the rest.
- Owner gates, which are not upstream: `../delegate/references/owner-gates.md` is read at setup, and Resuming runs also on a fresh start with no ledger, because a lost workspace looks like one: its restore runs before the ledger is read, its other steps once the ledger exists, created first with its identity line when none exists and no Execution status recreates it.
- State walk, which is not upstream: in the final review's fix pass, a fix to protocol text (text that names states and the events between them, or a rule that holds across steps, recognized by a sentence that is read on more than one path) gets one, with the states and paths listed before the edit, each read again after it, and the walk ledgered as `Final: walked <finding>; ...`; one rationalization row.
- Final review: the reviewer reads the template's prompt from a file that `../delegate/scripts/prompt-file` writes to the workspace, and the dispatch names that file and fills each placeholder by its name; the template is never pasted, condensed or reworded, and the evidence reviewer's template goes out the same way.
- Scripts `task-start` and `task-done`: take the task's label from `../../delegate/scripts/task-brief --label`; `task-start` prints it as a third line, `label: <label>`; `task-done` ledgers `<label>: complete (...)`, names the log `task-N-slug-tests.log` and its failure message by the label, and stops before the test command when `task-brief` refuses the task.
- `task-done`: the log name is built from the label only, so a space in the workspace path stays as it is.
- Tasks are named by their label (`Task 3 rate-limiter`, or `Task 3` without a slug) in every ledger line format; `task-start` prints the label and `task-done` writes the completion line under it.
- The inline executor is the implementer: the core principle says the plan carries the decisions and the tests and the code are the executor's; "Work the steps" became "Work the task" (a failing test per acceptance line, then the code; dictated text placed word for word; a States block walked and ledgered as `<label>: walked <state>: <outcome>; ...`; steps only for a task with an owner gate or a mandated check, or from a plan written before plans had tasks without steps); the completion contract speaks of acceptance lines, `task-done` takes the command that runs the task's own test files, and the process graph, two rationalization rows and the example workflow follow. "A fully specified plan makes inline execution transcription plus testing" became a statement that the plan is written for a skilled developer, so inline execution needs a session model of the mid tier or above.
- The post-gate part of an unforeseen gate in a task without steps starts at the acceptance lines that remain, where it would start at the step after the stop.
- The evidence review's template goes out as a file, as "Final review" says; the Review Focus parenthesis speaks of what no task's acceptance lines cover; the TDD sentence speaks of tasks, not steps; the example workflow names Task 1 by its label.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Two bash scripts that read the plan, run the task's test command as given by the executor, and write under the workspace in the repository; no network, no credentials, no hooks, no tool restrictions, no encoded content. The "Continuous execution" and "Rulings, not stalls" rules instruct the agent not to ask between tasks; that is the workflow the user chose (two review gates) and not an override of user instructions, and the stop conditions remain.
- Quality: description rewritten. Trigger check: "execute this plan inline" triggers; "implement this feature" without a plan does not (it goes to `discover:approach` and `build:plan`). Body long (373 lines upstream, 320 here) but a workflow skill that runs once per plan; no references needed. Dependencies stated: bash, git, `build:delegate` scripts, `practice` and `review` skills. Scope stated. Agent-neutral (harness features named generically).
- Fit: `.superpowers/sdd/` patched to `tmp/build/`; `docs/superpowers/plans/` to `docs/plans/`; worktree skill folded into a section without package installs; test commands generic with `devenv test` under a conditional heading; commit rule per task on a branch, never on main. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: `task-done` renders the test command for the ledger line and quotes arguments containing spaces or shell metacharacters; an argument containing a single quote is still rendered unquoted. Cosmetic, ledger only.
- The scripts have no file extension, so the prerequisite validator does not scan them; they contain no prerequisite terms anyway.
