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
It turns a finished branch into the user's second review gate: full check green, plan file removed, then the user chooses merge, pull request or keep.
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

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Runs git merge, push and worktree removal only after the user picks a menu option; discard needs the typed word; no `--force` on its own; no network beyond `git push` on request; no credentials, hooks, scripts or encoded content.
- Quality: description rewritten. Trigger check: "the plan is done, wrap up the branch" triggers; "commit this" does not. Body 225 lines upstream, 244 here; proportionate. Dependencies: git, optionally a forge CLI. Scope stated.
- Fit: test suite wording generic with `devenv test` conditional; plan-file removal step added per the plan-location decision; ADR check under a documents heading. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: removing the plan (Step 2) happens after the full check (Step 1) and adds a commit; the check is not re-run, since deleting a Markdown file cannot change the tests, but a hook that lints Markdown links would still run on that commit through the normal commit hooks.
