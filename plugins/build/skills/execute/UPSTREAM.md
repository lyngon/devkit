# execute

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/executing-plans`
- **Upstream name**: `executing-plans`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The inline executor: one context does every task from a fully specified plan, with a ledger that survives compaction so a resumed session never redoes a finished task, and one fresh reviewer at the end.
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

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Two bash scripts that read the plan, run the task's test command as given by the executor, and write under the workspace in the repository; no network, no credentials, no hooks, no tool restrictions, no encoded content. The "Continuous execution" and "Rulings, not stalls" rules instruct the agent not to ask between tasks; that is the workflow the user chose (two review gates) and not an override of user instructions, and the stop conditions remain.
- Quality: description rewritten. Trigger check: "execute this plan inline" triggers; "implement this feature" without a plan does not (it goes to `discover:approach` and `build:plan`). Body long (373 lines upstream, 320 here) but a workflow skill that runs once per plan; no references needed. Dependencies stated: bash, git, `build:delegate` scripts, `practice` and `review` skills. Scope stated. Agent-neutral (harness features named generically).
- Fit: `.superpowers/sdd/` patched to `tmp/build/`; `docs/superpowers/plans/` to `docs/plans/`; worktree skill folded into a section without package installs; test commands generic with `devenv test` under a conditional heading; commit rule per task on a branch, never on main. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: `task-done` renders the test command for the ledger line and quotes arguments containing spaces or shell metacharacters; an argument containing a single quote is still rendered unquoted. Cosmetic, ledger only.
- The scripts have no file extension, so the prerequisite validator does not scan them; they contain no prerequisite terms anyway.
