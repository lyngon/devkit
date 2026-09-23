# tdd

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/test-driven-development`
- **Upstream name**: `test-driven-development`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The engineering conventions say to reproduce a bug first and to keep the reproduction as a regression test; this skill is the procedure that makes an agent do that under pressure, with the rationalizations it will reach for named and answered.
`writing-good-tests.md` is the sharpest short text we have on tests that catch real breaks rather than mock behaviour.

## Local patches

- Renamed `test-driven-development` to `tdd`.
- Rewrote the description to say what the skill does (failing test first, watch it fail, minimal code, watch it pass, refactor, delete code written before its test) and when to use it (any feature, bug fix, refactor or behaviour change, before production code), with "add a retry to the HTTP client" as the example and renames, prose edits and configuration named as non-triggers.
- Moved `writing-good-tests.md` to `references/writing-good-tests.md` and updated the link in SKILL.md.
- Replaced the `<Good>` and `<Bad>` inline HTML blocks with `**Good:**` and `**Bad:**` labelled paragraphs that carry the upstream caption; the code is unchanged.
- Replaced the whole-line bold step labels in the bug-fix example (`**RED**`, `**GREEN**`, ...) with level-3 headings, because markdownlint MD036 rejects emphasis used as a heading.
- Replaced the bare `npm test path/to/test.test.ts` instruction in Verify RED and Verify GREEN with "run the repository's test command for that file, for example:" followed by the upstream command; the bug-fix example says the same before its `$ npm test` output.
- "Other tests means the project's suite" now reads "the repository's whole suite"; the example commands (`pytest`, `npm test`, `cargo test`) stay examples of "whatever the repository uses".
- "Exceptions (ask your human partner)" became "Exceptions (ask the user)"; "Ask your human partner" in the "when stuck" table and "your human partner's permission" in the final rule became "the user".
- Added one sentence under "When to use": a mechanical rename with no behaviour change needs no new test, the existing tests prove it changed nothing; and the "Refactoring" bullet now says the tests exist before you start and stay green. Reason: the description must not fire on "rename this variable" while refactoring stays in the "always" list.
- The debugging integration now invokes `practice:debug` before the failing test is written; added a short "Verification" section that invokes `practice:verify` before claiming the work is done (upstream referenced neither skill from this file).
- Removed every em dash and en dash (rationalization table, warning signs, principle paragraphs); replaced "≠" in prose with words.
- Renamed headings to sentence case and removed trailing punctuation from them; "Red Flags - STOP and Start Over" became "Red flags: stop and start over".
- The iron law and final rule code blocks are fenced as `text` (markdownlint MD040); the final rule uses `->` instead of the Unicode arrow.
- "not typos" became "not a spelling mistake" in Verify RED and the checklist, because `typos` is a baseline term for the prerequisite validator.
- In `writing-good-tests.md`: "your human partner's correction" and "your human partner's question" became plain rules ("Ask: are we testing the behaviour of a mock?", "Ask: do we need to be using a mock here?"); the sentence naming `superpowers:writing-skills` became "Documents that instruct agents are tested by the consuming agent's behaviour"; the gate function blocks use `->` and are fenced as `text`; the arrow-and-outcome sentence "Wrong answers → test utility" became a sentence.
- Spelling normalised to "behaviour" in prose (code identifiers untouched).
- Reflowed every prose paragraph to one sentence per line; blank lines added around lists and fences.
- Dropped the upstream "Announce at start" convention (none in this file) and every reference to superpowers paths.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text with code examples; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content.
- Quality: description rewritten to state what and when. Trigger check: "add a retry to the HTTP client" triggers; "rename this variable" and "tidy the README" do not. Body 330 lines upstream plus a 198-line reference; the reference moved to `references/`. No runtime dependencies. Exceptions stated. Agent-neutral; examples are TypeScript with jest and vitest, kept as illustrations.
- Fit: inline HTML tags removed; test command generic; "human partner" voice replaced; the delete rule kept deliberately: upstream's strictness (code written before its test is deleted, exceptions only with the user's permission) is the point of the skill, and softening it would leave the rationalization table answering a rule that no longer exists. Does not write devkit-owned files. Overlap: the `conventions` plugin's engineering skill states the testing rules in three lines; this is the procedure behind them, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
