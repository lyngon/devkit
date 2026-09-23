# debug

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/systematic-debugging`
- **Upstream name**: `systematic-debugging`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The engineering conventions say to start a bug fix by reproducing it end to end; this is the full procedure, with the three-failed-fixes rule that turns a thrashing session into an architecture question, and three techniques (backward tracing, defense in depth, condition-based waiting) that come up in every codebase.

## Local patches

- Renamed `systematic-debugging` to `debug`.
- Rewrote the description to say what the skill does (root cause before any fix: read the error, reproduce, check recent changes, gather evidence, one hypothesis, minimal test, then a failing test first) and when to use it (any bug, failing test, unexpected behaviour, build failure or performance problem, before proposing a fix), with "the integration test started failing after the refactor" as the example and "adding a feature" as a non-trigger.
- Moved `root-cause-tracing.md`, `defense-in-depth.md`, `condition-based-waiting.md` and `condition-based-waiting-example.ts` into `references/`, and `find-polluter.sh` into `scripts/`; every link and mention updated to the new paths.
- Dropped `test-academic.md`, `test-pressure-1.md`, `test-pressure-2.md`, `test-pressure-3.md` and `CREATION-LOG.md`: the upstream author's own eval scenarios and creation notes, not material for the agent.
- Phase 4 invokes `practice:tdd` (was `superpowers:test-driven-development`) and `practice:verify` (was `superpowers:verification-before-completion`).
- The heading "your human partner's Signals You're Doing It Wrong" became "Signals from the user that you are doing it wrong"; "Discuss with your human partner" became "Discuss with the user"; "Manager wants it fixed NOW" became "The user wants it fixed now".
- The user signal "Ultra-think this" became "Think harder about this", because "ultrathink" is a keyword of one harness.
- "See Phase 4.5" became "Phase 4, step 5", since there is no such heading.
- The Phase 1 multi-layer bash example is kept as an illustration of layer-by-layer evidence, introduced as "a signing pipeline with four layers".
- `scripts/find-polluter.sh` rewritten: the test command is a third argument (`find-polluter.sh <path-to-check> <test-glob> <test-command>`) instead of a hard-coded `npm test`, run through `bash -c` so the command can carry flags; `set -euo pipefail`; test files are read into an array line by line instead of word-splitting `$TEST_FILES`; `find` limited to `-type f`; a missing match list and a pre-existing polluted path exit 2 up front instead of skipping each file with a warning; usage errors go to stderr; the emoji in the output are gone. The exec bit is kept. The usage text and the call in `root-cause-tracing.md` show the third argument.
- `references/condition-based-waiting-example.ts`: the three-line header comment naming the Lace project and the session date is replaced by two neutral lines; the rest is verbatim, including the `Lace*` type names, since it is an example nothing runs.
- Dropped the "Real-World Impact" sections of `root-cause-tracing.md` and `condition-based-waiting.md` (session date, test counts, pass rates) and the "1847 tests" figures in `defense-in-depth.md`, replaced by "the whole suite passed"; the "Real Example" and "Example from Session" walk-throughs are kept as "Example".
- `condition-based-waiting.md` says the example file is an example to adapt, not code that anything runs; the "Common mistakes" pseudo-list became a real list.
- `root-cause-tracing.md` names `npm test` as "the repository's test command (here `npm test`)" before the capture command; the call-chain listing uses `->` instead of the Unicode arrow.
- Removed every em dash and en dash; "≠" in prose became words; the `≥`/`<` comparisons in Phase 4 are spelled out ("3 or more", "fewer than 3").
- Headings renamed to sentence case with no trailing punctuation; "Red Flags - STOP and Follow Process" became "Red flags: stop and follow the process".
- Whole-line bold pseudo-headings ("**BEFORE attempting ANY fix:**", "**Find the pattern before fixing:**", "**Scientific method:**", "**Fix the root cause, not the symptom:**") became plain sentences (markdownlint MD036); the iron law and evidence blocks are fenced as `text`.
- The supporting-techniques list now links into `references/` and mentions `scripts/find-polluter.sh`.
- Spelling normalised to "behaviour" in prose (code and graph labels untouched).
- Reflowed every prose paragraph to one sentence per line; blank lines added around lists and fences; continuation lines under numbered steps indented to the step text.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. One bash script that runs the given test command per test file and checks for a path; no network, credentials, hooks, tool restrictions, overrides or encoded content. The test command is user input executed through `bash -c`, by design: the script exists to run it. The TypeScript file is an example, never executed.
- Quality: description rewritten. Trigger check: "the integration test started failing after the refactor" triggers; "add pagination to the list endpoint" does not. Body 283 lines upstream, techniques in `references/`. Dependencies: bash for the script. Scope stated. Agent-neutral.
- Fit: the upstream eval scenarios and creation log dropped; script test command made an argument; references moved; "human partner" voice replaced. The Phase 1 example uses macOS `security` and `codesign`; kept as an illustration only. Does not write devkit-owned files. Overlap: the engineering convention's one line on reproducing bugs; this is the procedure, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
