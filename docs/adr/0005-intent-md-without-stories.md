# `INTENT.md` holds product-level intent only, not stories

Purpose, audiences, done, failure and non-goals were spread across `README.md` and `CLAUDE.md`, where nobody re-reads them when scope creeps.
We add `INTENT.md` at the root, borrowing the name and the product-level idea from the intentdocs convention (<https://www.intentdocs.com/intent-md>), but deliberately without its personas, user journeys, stories, acceptance criteria and release sections.
Those are a backlog, go stale within weeks, and duplicate the issue tracker; the product-level statement is the part that stays true for years.

## Consequences

- Four root documents, each with one job: `INTENT.md` why and for whom, `README.md` how to use, `CLAUDE.md` how to work, `CONCEPTS.md` terms.
- `INTENT.md` changes only when the purpose changes. Stories and acceptance criteria go to the issue tracker, never here.
- The intentdocs tool is not used and the file is not kept compatible with it.
