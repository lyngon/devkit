# plan

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/writing-plans`
- **Upstream name**: `writing-plans`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

Nothing in the devkit turned a settled design into an executable plan.
This skill's task shape (files, interfaces, no placeholders) is what lets a fresh implementer or a mid-tier model execute without the designer's context, and its self-review catches the gaps before execution starts.

## Local patches

- Renamed `writing-plans` to `plan`.
- Description rewritten to say what the skill does and when to use it, keeping "write the plan" and "plan the implementation" as triggers and naming `discover:approach` as the home of design questions.
- Dropped `plan-document-reviewer-prompt.md`: the upstream SKILL.md no longer uses it, self-review replaced the subagent.
- Dropped the "Announce at start" line and the "Context" line about `superpowers:using-git-worktrees` (the executor decides on a worktree at setup).
- Plan location changed from `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (a whole file, user preference overriding) to a `## Plan` section appended to `docs/plans/YYYY-MM-DD-<slug>.md`, the file `discover:approach` starts with its `## Design` section; a new "Where the plan lives" section explains this, the case where the design came from elsewhere (create the file with a `## Design` section pointing at the spec), and that `build:finish` removes the file when the branch is done.
- Plan header changed from an H1 `# [Feature Name] Implementation Plan` to the `## Plan` heading, with `Global Constraints` and `Review Focus` as H3 under it; the header keeps the upstream heading names so executors and reviewers find them. The "For agentic workers" line names `build:delegate` (recommended) or `build:execute`. The `Spec:` field points at the `## Design` section of the same file or the external spec it points at.
- Task structure: example paths rewritten to `<package>/src/...` and `<package>/tests/...` with a sentence saying the repository's layout and declared test command decide; step titles reworded ("Run the test to verify it fails"). Added the commit rule: one commit per task on the feature branch, Conventional Commits, one concern per commit, more commits only when the plan says so, never on main.
- "File structure" gained a bullet that the repository's layout decides where files go.
- Execution handoff: the two options renamed to Delegate (`build:delegate`) and Inline (`build:execute`); the recommendation sentence kept; added that the plan is committed on the feature branch (creating the branch when still on main, because nothing is committed on main without consent), that the user reviews the plan now and the finished branch later and is not asked between tasks, and the sentence "You will not be asked again until the branch is finished" in the handoff text. The handoff messages are fenced `text` blocks instead of bold paragraphs. "Subagent-driven" and "Native" became "Delegate" and "Inline".
- Added a `## With the Lyngon documents` section: decisions meeting the ADR bar go to `docs/adr/` via `discover:domain-model`, settled terms to `CONCEPTS.md`, and the plan is none of the four documents.
- Self-review rewritten as a numbered list with the same four checks (two more were added later, see below).
- "your human partner" replaced by "the user" throughout.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; the "No placeholders" list reworded without dashes; `pytest` example command kept as an illustration.
- Added a pointer to `WORKFLOW.md`, the shared flow document, symlinked into this skill from the devkit's `shared/`.
- Added a `## Checks and commands` section after the task structure: every check the plan mandates is shown failing without its property and passing with it, with the `pipefail` and `grep -q` false negative as the example; a command a person runs by hand is POSIX sh or runs through `bash -c`, with a pointer to `conventions:shell` when the conventions plugin is installed. "No placeholders" gained "a check without a control".
- Self-review gained two checks: 5, every mandated check proven both ways; 6, every block of dictated prose checked against the repository's recorded decisions, the gates and rules in its agent instructions, and the design's and plan's own findings. `## With the Lyngon documents` names the ADRs, `CLAUDE.md` and `CONCEPTS.md` for check 6.
- The execution handoff names the pull request that `build:finish` opens as the second gate, and says the rulings are presented in its description; between the gates the executor asks the user nothing.
- Owner gates, which are not upstream: a `### Owner Gates` index in the plan header; an `## Owner gates` section with the gate step, its fields and its rules; every task ends with at least one commit; a "No placeholders" item and self-review item 7 for gates; the handoff asks for pre-approvals by ID and records them in the index before invoking the executor.
- Owner gates, which are not upstream: a step title says "owner gate" only in a marker, and the executor refuses any other step title that says it and a task the index names without its marker.
- The pointer to `WORKFLOW.md` names the user's two review gates; the first handoff template's clause about the owner gates not pre-approved is left out when the plan declares none; self-review item 7 says "an action an executor must stop for" where it said "stop-list action", a term the skill never defined.
- Owner gates, which are not upstream: the executor removes a gated task's temporary files once the evidence review is clean, not before; a character a hook rejects in a pre-approval, or a `|` that would break the index table, is replaced by its plain form.
- Owner gates, which are not upstream: the gate record commit body starts with the line `Owner gate: <id>`.

- Departs from upstream's rule of complete code in every step: a task has Intent, Acceptance and Commit blocks and no steps, and holds no test code or implementation, because the implementer writes the tests and the code. The "Bite-sized granularity" section is removed, "Overview" is rewritten around what the implementer cannot know or must not decide, and "No placeholders" is rewritten to match.
- Added dictated text (a task's blocks of text placed word for word, located by file, section and anchor, with a States block for protocol text), tasks with steps only for an owner gate or a mandated check, a slug in every task heading and step, and the rule that tasks and steps are referred to by label.
- Self-review rewritten to nine items: the line test, a size check and a check of dictated text against its states were added, and the type-consistency check also covers references to tasks and steps.
- Execution handoff: a recommendation rule (`build:execute` for about five tasks or fewer without an owner gate the agent performs, `build:delegate` otherwise), the plan's size and longest task in both messages, and an inline-review warning for an owner gate the agent performs.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. No network access, no credential reads, no scripts, no hooks, no tool restrictions, no instruction override, no encoded content, writes only the plan file in the repository.
- Quality: description rewritten to state what and when. Trigger check: "the design is settled, write the implementation plan" triggers; "fix this typo" and "which database should we use" do not. Body 192 lines upstream, 233 here after reflow; proportionate, no references needed. No runtime dependencies. Scope stated (before touching code; after a spec). Agent-neutral.
- Fit: upstream wrote plans to `docs/superpowers/plans/` (patched to `docs/plans/` with the shared design file), committed per step (patched to per task), and named superpowers executors (remapped). Does not write devkit-owned files. Overlap: none in the devkit; `discover:approach` produces the design this consumes.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: the plan is committed by this skill on the feature branch (creating the branch when on main) rather than left uncommitted for the executor, because a worktree created at execution time would not see an uncommitted file in the main checkout. Upstream never says who commits the plan.
