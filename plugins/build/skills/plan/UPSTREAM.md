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
This skill's task shape (files, interfaces, five steps each with expected output, no placeholders) is what lets a fresh implementer or a mid-tier model execute without the designer's context, and its self-review catches the gaps before execution starts.

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
- Self-review rewritten as a numbered list with the same four checks.
- "your human partner" replaced by "the user" throughout.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; the "No placeholders" list reworded without dashes; `pytest` example command kept as an illustration.
- Added a pointer to `WORKFLOW.md`, the shared flow document, symlinked into this skill from the devkit's `shared/`.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. No network access, no credential reads, no scripts, no hooks, no tool restrictions, no instruction override, no encoded content, writes only the plan file in the repository.
- Quality: description rewritten to state what and when. Trigger check: "the design is settled, write the implementation plan" triggers; "fix this typo" and "which database should we use" do not. Body 192 lines upstream, 233 here after reflow; proportionate, no references needed. No runtime dependencies. Scope stated (before touching code; after a spec). Agent-neutral.
- Fit: upstream wrote plans to `docs/superpowers/plans/` (patched to `docs/plans/` with the shared design file), committed per step (patched to per task), and named superpowers executors (remapped). Does not write devkit-owned files. Overlap: none in the devkit; `discover:approach` produces the design this consumes.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: the plan is committed by this skill on the feature branch (creating the branch when on main) rather than left uncommitted for the executor, because a worktree created at execution time would not see an uncommitted file in the main checkout. Upstream never says who commits the plan.
