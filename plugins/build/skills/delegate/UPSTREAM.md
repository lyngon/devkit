# delegate

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/subagent-driven-development`
- **Upstream name**: `subagent-driven-development`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The thorough executor: a fresh implementer per task so no context pollutes another, a spec-and-quality review after every task, a bounded fix loop with a breaker, and a whole-branch review at the end.
With the user reviewing only the plan and the finished branch, this per-task reviewer is what replaces the human eye on every commit.

## Local patches

- Renamed `subagent-driven-development` to `delegate`.
- Description rewritten to say what the skill does and when to use it, and that it is the default executor for more than a handful of tasks.
- Skill references remapped: `superpowers:executing-plans` to `build:execute`, `superpowers:requesting-code-review` to `review:request`, `superpowers:finishing-a-development-branch` to `build:finish`, "brainstorm first" to `discover:approach` and `build:plan`.
- Prompt templates moved from the skill directory into `references/` (`implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`); links and graph node labels updated. In each template, `Subagent (general-purpose):` replaced by `Dispatch a subagent with:`; the `description`, `model` and `prompt` fields, the no-subagents contract, the report contract, the four statuses and the calibration rules kept; the `[MODEL]` note reworded without a dash; the placeholder lists rewritten as bullets with colons; the templates are fenced as `text`.
- Implementer template: the commit step now says one commit per task on the current branch, Conventional Commits, one concern per commit, never on main; added that tools come from the repository's declared environment (never install anything) and that a check or hook is never disabled, skipped or weakened (report instead). Added a placeholder list.
- Task reviewer template: "the human decides" became "the user decides"; "spec/design" became "spec or design".
- Scripts: `sdd-workspace` renamed to `workspace`; base directory changed from `<repo-root>/.superpowers/sdd` to `<repo-root>/tmp/build`, with the self-ignoring `.gitignore` (`*`) written inside `tmp/build/`; comments reworded generically (the `.git/` protection is attributed to agent harnesses in general rather than Claude Code, `tmp/` named as the Lyngon scratch directory, "legacy" marker-less workspaces described as created by hand or by an older version), the plan-path marker logic kept unchanged. `task-brief` and `review-package` call `workspace` and document the new default paths; the "(#2040)" issue reference and "marketplace packages" wording replaced by "some plugin installers strip Unix exec bits"; the two `CDPATH= cd` idioms in `workspace` became `CDPATH='' cd` so the script is clean under the repository's shell lint (same behaviour). Exec bits kept.
- Setup: the worktree paragraph pointing at `superpowers:using-git-worktrees` replaced by an `### Isolated workspace` section (ask once, prefer the harness's native worktree tool, fall back to `git worktree add .worktrees/<branch>` with `.worktrees/` git-ignored, no package installs, never on main without consent, the plan is already committed on the branch, implementers work in the worktree) with a `#### With devenv` subsection.
- Ledger: first line changed from the upstream `# SDD ledger` header (which carried an em dash) to `# build ledger: plan <path>`; the clause about a stray ledger at the old flat path `.superpowers/sdd/progress.md` removed; added that `tmp/` may be emptied at any time.
- Spec pointer: "If the plan names a Spec" became "the `## Design` section of the same file, otherwise the external spec the plan header points at".
- Stop conditions: the four upstream stops plus a fifth (a check or hook that could only be passed by disabling, skipping or weakening it), the rule never to do so and never to let an implementer do so; two rationalization rows added (skipping a failing hook, checking in between tasks). "the four named below" became "the five named below".
- Continuous execution names the user's two review gates.
- Final review: the cross-plugin file reference `[code-reviewer.md](../requesting-code-review/code-reviewer.md)` replaced by invoking `review:request`, which carries the template; inputs listed as the review package path, the plan and its Design section, the Review Focus verbatim, and the ledger's deferred-minor, parked and `Ruling:` lines. The graph node renamed accordingly.
- Finish: "Deferred minors" list added next to "Rulings I made" (upstream collected only rulings), so `build:finish` can open the pull request description with both; ends by calling the Skill tool for `build:finish`.
- Ledger line formats use semicolons where upstream used em dashes (`Ruling: <what>; <why>; <cost>`, `Task <N>: parked; <finding>; Ruling: <why>`, the fix round line).
- Model selection: "standard model" became "mid-tier model" so the three tiers read cheap, mid-tier, most capable; no vendor model named (as upstream). "Task complexity signals" rewritten as a bullet list without arrows.
- Example workflow: paths rewritten to `docs/plans/2026-09-23-recovery.md` and `scripts/workspace`; the answer `~/.config/superpowers/hooks/` replaced by a neutral one; the opening announcement dropped; the "Rulings I made" and "Deferred minors" lists shown; closing line invokes `build:finish`.
- The "When to use" graph: nodes renamed to `build:delegate`, `build:execute` and "Manual execution, or discover:approach and build:plan first"; "Partner chose inline" became "User chose inline".
- "Announce at start" line dropped; "your human partner" replaced by "the user" throughout.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; the numbered BLOCKED list ends each item with a full stop; bold labels end in a full stop or colon.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Three bash scripts write only under `tmp/build/` in the repository and read git; no network, no credentials, no hooks, no tool restrictions, no encoded content. Subagent prompts contain a "You do not dispatch subagents" contract, which limits rather than widens execution. The continuous-execution rule is the chosen workflow, stop conditions remain.
- Quality: description rewritten. Trigger check: "execute the plan with subagents" and a plan handoff that chose delegation trigger; "help me debug this test" does not. Body is the longest in the set (568 lines upstream, 499 here with the templates in `references/`). Dependencies: bash, git, a subagent tool, `practice` and `review` skills. Scope stated. Agent-neutral.
- Fit: paths patched as for `execute`; cross-plugin file reference to the reviewer template replaced by invoking `review:request`; worktree section folded; no package installs; commit rule per task. Does not write devkit-owned files. Overlap: `build:execute` is the inline alternative; both are wanted, they share the workspace.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: `workspace` adopts any marker-less directory under `tmp/build/` whose name matches the plan slug, so a directory created by hand with that name becomes the plan's workspace; harmless in practice, kept as upstream.
- The scripts have no file extension, so the prerequisite validator does not scan them; they contain no prerequisite terms anyway.
