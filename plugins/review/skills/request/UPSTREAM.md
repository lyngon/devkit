# request

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/requesting-code-review`
- **Upstream name**: `requesting-code-review`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

Both executors need a reviewer that takes a plan, a review-focus list and the executor's rulings, which a generic review command does not.
The template gives the reviewer exactly that context and nothing of the requester's session, and its "declined to judge" list stops findings from being dropped silently.

## Local patches

- Renamed `requesting-code-review` to `request`; the H1 is "Request a code review".
- Rewrote the description to say what the skill does and when to use it, naming `build:delegate`, `build:execute`, "before merging" and "get this reviewed before I merge" as triggers, and "there is code to review" to keep design discussions out.
- Moved `code-reviewer.md` to `references/code-reviewer.md` and updated both links.
- "After each task in subagent-driven development" became "After each task in `build:delegate`"; added "At the end of `build:execute`" to the mandatory list.
- "Push back if reviewer is wrong" and the "If reviewer wrong" list now point to `review:receive` for evaluating and answering the findings.
- Unified the placeholder syntax on `{NAME}`: upstream uses `{NAME}` in SKILL.md and `[NAME]` in the template.
- Added the optional placeholders `{REVIEW_PACKAGE}` (the file that `build:delegate`'s `review-package` script prints, so the reviewer reads one file), `{REVIEW_FOCUS}` (the plan's Review Focus section verbatim, with "check each of these deliberately and report on each one") and `{RULINGS}` (the ledger's `Ruling:` lines, with "weigh these calls; disagree where warranted"), each as its own template section, plus the rule to leave out a section with nothing to fill it.
- Added `model: {MODEL}` to the template header and one sentence in SKILL.md to specify the model explicitly, the most capable tier for a whole-branch review, matching how the build executors dispatch it.
- Replaced `Subagent (general-purpose):` with the neutral "Dispatch a subagent with:".
- Replaced `git worktree add /tmp/review-[SHA] [SHA]` with `git worktree add <temporary directory> <sha>`, so the template names no fixed path.
- "The executor rules on each line" became "The requester rules on each line": the skill is also used outside the build executors.
- Added a "Declined to judge" heading to the reviewer's output format and to the example output, so the list the template asks for has a place in the report.
- Added step 3's rule to rule on every "Declined to judge" line, and a note under step 1 that `HEAD~1` covers one commit only, so multi-commit tasks and branches use the recorded base or the merge base.
- Added a third rationalization row ("It's a small change, review is overkill").
- Rewrote the example with a neutral plan path (`docs/plans/2026-09-23-deployment.md`) and a recorded base commit instead of grepping `git log` for a task name.
- Sentence-cased the headings; removed the em dashes; reflowed prose to one sentence per line; gave every fenced block a language and wrapped the template in a four-backtick fence so its inner `bash` fence renders.
- Lower-cased the severity labels in the output format headings ("Critical (must fix)") and removed "Senior Code Reviewer" capitalization; no change of meaning.
- Dropped nothing else; the read-only rule, the no-subagents rule, the spec-as-vision section, the check lists, the calibration, the critical rules, the rationalization table, the red flags and the example output are kept.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Prompt text and a subagent template; the template makes the reviewer read-only on the checkout and forbids it from dispatching further subagents. No network, credentials, scripts, hooks, tool restrictions, overrides or encoded content.
- Quality: description rewritten. Trigger check: "get this reviewed before I merge" triggers; "review this design with me" does not. Body 95 lines plus a 198-line template moved to `references/`. Dependencies: git, a subagent tool. Scope stated. Agent-neutral.
- Fit: superpowers references remapped; review-focus and rulings placeholders added for the build plugin; the temporary worktree path made neutral. Does not write devkit-owned files. Overlap: Claude Code's own review command exists but takes no plan context; this template is what `build` needs, and it is what a user asks for when they say "get this reviewed".
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: the upstream template asks for a "Declined to judge" list but its output format has no heading for it, so a reviewer following the format literally has nowhere to put the list; the heading was added. Upstream's example computes the base with `git log --oneline | grep "Task 1"`, which breaks on multi-commit tasks; the executors record the base instead, and the example now says so.
