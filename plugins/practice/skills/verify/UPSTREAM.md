# verify

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/verification-before-completion`
- **Upstream name**: `verification-before-completion`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The shortest skill in the set and the one that closes the gap between "should pass" and "passed": a claim needs the command and its output in the same message.
The engineering conventions say to report faithfully; this is how.

## Local patches

- Renamed `verification-before-completion` to `verify`.
- Rewrote the description to say what the skill does (run the command that proves a claim and read its output before claiming that something works, passes, is fixed or is done) and when to use it (before any completion or success claim, before committing, opening a pull request, handing over or moving on), keeping the upstream phrase "evidence before assertions, always" and naming a claim-free question as a non-trigger.
- Added the row "Full check green" to the claims table: requires the repository's full check run in this session with exit 0; a green test run, a green linter or a run from an earlier session is not sufficient.
- Added a `## With devenv` section saying the full check is `devenv test`, which runs every git hook on every file plus the repository's tests, and that "Full check green" means that command ran in this session and exited 0.
- "VCS diff" became "the version control diff" in the claims table and the agent delegation pattern.
- "About to commit/push/PR" became "About to commit, push or open a pull request"; "PR creation" became "opening a pull request".
- Removed the "≠" comparisons from the rationalization table ("Confidence is not evidence", "A linter is not a compiler", "Exhaustion is not an excuse").
- Headings renamed to sentence case with no trailing punctuation; "Red Flags - STOP" became "Red flags: stop".
- The iron law, gate function and key pattern blocks are fenced as `text`; the arrows in the patterns are `->`; the ✅ and ❌ markers are kept.
- Reflowed to one sentence per line; blank lines added around lists and fences.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content.
- Quality: description rewritten. Trigger check: about to say "all tests pass" triggers; "what does this function do" does not. Body 120 lines upstream, proportionate. No dependencies. Scope obvious. Agent-neutral.
- Fit: full-check row added with a conditional `devenv test` line. Does not write devkit-owned files. Overlap: the engineering convention's "report faithfully" line; this is the procedure, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
