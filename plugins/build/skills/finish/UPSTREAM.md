# finish

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/finishing-a-development-branch`
- **Upstream name**: `finishing-a-development-branch`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

Both executors end here.
It turns a finished branch into the user's second review gate: full check green, plan file removed, then the branch pushed and its pull request opened for the user's review.
The discard path with a typed confirmation and the ownership rule for worktree cleanup are the safety the executors rely on.

## Local patches

- Renamed `finishing-a-development-branch` to `finish`.
- Description rewritten to say what the skill does and when to use it.
- Step 1 "Verify Tests" became "Run the full check": the repository's full check (every lint and every test), with `npm test`, `cargo test`, `pytest` and `go test ./...` named as examples of a test command rather than the assumption; a `### With devenv` subsection says the full check is `devenv test`. The failure message says "Full check failing".
- New Step 2 "Remove the plan": when the branch carries `docs/plans/YYYY-MM-DD-<slug>.md`, remove it in a final commit `chore: remove the plan for <slug>`, with one sentence on why (history holds the work, decisions were recorded as decisions). Under `### With the Lyngon documents`: check the Design section for a decision meeting the ADR bar that is not yet in `docs/adr/` and record it first via `discover:domain-model`. The brief asked for a `####` heading here; markdownlint MD001 forbids skipping from `##` to `####`, so it is `###`.
- Later steps renumbered (detect environment 3, base branch 4, options 5, execute 6, cleanup 7) and the cross-references in the bash comment and the prose updated.
- Option 1 runs the full check on the merged result (`<full check>` placeholder instead of `<test command>`).
- Option 2: the pull request description opens with the "Rulings I made" and "Deferred minors" lists from the executor's final message, or a short summary when no executor produced the branch; "pull/merge request" reads "pull request (or merge request)".
- Menu wording: "Keep the branch as-is" became "as it is"; "Create PR" became "Create a pull request" in the quick reference.
- Cleanup: "Superpowers created this worktree" became "the executor created this worktree"; the refused-removal example file kinds no longer mention "uncommitted plans".
- Rationalization table: one row added about leaving the plan file; "Tests passed earlier" became "The check passed earlier"; "your human partner" replaced by "the user".
- "Announce at start" line dropped; the core principle gained "remove the plan".
- Placeholders in prose use square brackets (`[your best guess]`, `[name]`, `[path]`) where upstream used angle brackets outside code, because markdownlint reads those as inline HTML; placeholders inside fenced blocks keep angle brackets.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; tables given leading and trailing pipes.
- Step 2 resolves the plan workspace (`tmp/build/<slug>/`, through `build:delegate`'s `workspace` script) before removing the plan, since the executors now hand it over instead of deleting it. Under `### With the Lyngon documents`: list the executor's deferred minors and the ledger's `minor (deferred)` and parked lines, ask the user which go to `docs/TODO.md`, write those with today's date and commit them with the plan removal; a branch without a ledger says so and moves on.
- Step 7 renamed "Clean up the plan workspace and the worktree": it removes the plan workspace first, on the merge and discard paths only; options 2 and 3 keep it because the work has not landed. The cross-references in options 1 and discard name both, and the quick reference's "Keep worktree" column became "Keep worktree and plan workspace".
- Rationalization table: a row added for deferred minors left in the executor's message.
- Option 2 ends the report with the landing steps for after the forge merges the pull request (switch to the base, `git pull --ff-only`, remove the plan workspace and the worktree, delete the branch, in an order git accepts), and a note on `-D` after a squash or rebase merge. The quick reference gained a row for them, and the rationalization table a row for the local base branch catching up on its own.
- The integration menu is gone. Step 5 pushes the branch and opens the pull request without asking, as the user's standing instructions say; merging locally, keeping the branch and discarding moved to Step 6, "Other outcomes, on request". Without a remote it reports and keeps the branch, without a forge CLI it hands over the creation link, and an existing pull request gets its description updated. The description lists what changed and why, decisions for the user, the executor's rulings and deferred minors with a link to the plan at the parent of the plan-removal commit, unfixed review findings, and the verification. Step 3's table says how the branch is pushed instead of which menu to show; Step 4 takes the base without asking for a pull request and asks only before a local merge. The description, the overview, Step 1's last line, Step 7's opening, the quick reference and the rationalization table follow, with rows for asking before the push and for amending a pushed commit.
- Step 2 collects the deferred findings instead of asking about them; they go into the pull request description, and Step 5's report asks which go to `docs/TODO.md` after the pull request is open, committing the chosen ones as a new commit; Step 6's outcomes ask the same before Step 7 removes the workspace. Step 5 runs the full check again when Step 2 added commits. The rationalization table gained a row against asking before the push, and the base-branch row applies to a local merge.
- Step 5 asks once, right before the push, unless the user's standing instructions cover pushing and opening a pull request; a `### With the Lyngon workflow` section at its end says that `conventions:engineering`'s do. The ask has a template, and its answer covers the branch's later pushes. The description and the rationalization rows about asking before the push and about the TODO question follow.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Runs git merge, push and worktree removal only after the user picks a menu option; discard needs the typed word; no `--force` on its own; no network beyond `git push` on request; no credentials, hooks, scripts or encoded content.
- Quality: description rewritten. Trigger check: "the plan is done, wrap up the branch" triggers; "commit this" does not. Body 225 lines upstream, 244 here; proportionate. Dependencies: git, optionally a forge CLI. Scope stated.
- Fit: test suite wording generic with `devenv test` conditional; plan-file removal step added per the plan-location decision; ADR check under a documents heading. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: removing the plan (Step 2) happens after the full check (Step 1) and adds a commit; the check is not re-run, since deleting a Markdown file cannot change the tests, but a hook that lints Markdown links would still run on that commit through the normal commit hooks.
- 2026-09-29: pushing and opening a pull request no longer wait for a menu choice (ADR 0016 and the standing instructions in `conventions:engineering`); merging, force-pushing and discarding still wait for the user.
- Owner gates, which are not upstream: Step 2 recreates a paused run's ledger from the plan's `## Execution status` with `../delegate/scripts/execution-status restore` and collects the ledger's `Gate` lines; the description gains an "Owner gates" list; one rationalization row.
