# Decision record format

Single source in `shared/` of the Lyngon devkit marketplace; plugins symlink it.
A repository may override it with `docs/conventions/decision-record.md`.

Format adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT).
The MIT license text is `shared/LICENSE-mattpocock`; the provenance record is `plugins/discover/skills/domain-model/UPSTREAM.md`.

A decision record states one decision the code cannot show, and exists only while the decision holds.
The term is decision record. "ADR" names a numbered file that carries a status and is never deleted, and a decision record is none of the three.

## When to write one

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

What usually passes:

- A deliberate deviation from the obvious path, which the next agent would otherwise "fix".
- A constraint that is not visible in the code: compliance, a contract, a platform, a response-time budget.
- A rejected alternative that looks attractive, so that nobody proposes it again.
- A boundary or scope decision. The explicit no is as valuable as the yes.

What does not: anything the code or the tree shows, and anything a check enforces.

A decision that passes is recorded in the same change that makes it.

## Template

```md
# {The decision, stated as a sentence}

{One to three sentences: context, what was decided, why.}

Enforced by: {the name of the check, or judgment}
```

- One file per decision, in `docs/decisions/` at the repository root, created with the first record.
  In a repository with several contexts, a context's records live in the `docs/decisions/` of the package that owns the context.
- The file is named `<slug>.md`, where the slug is the title in kebab-case.
  It carries no number, because a record is referred to by its name.
- `## Considered options` and `## Consequences` are optional and come before the last line. Add the first when the rejected alternatives must not be proposed again, and the second for effects a reader would miss.
- The last line is `Enforced by:` followed by the name of the check that fails on a violation, by `judgment` when no check does, or by both when a check covers part of the decision.
- A record has no `Status:` line and no `## Change log`, because the tree holds what is true now and git holds the past.

## Editing and deleting

- A record is edited freely while its file name stays true.
- When the decision changes, the file is deleted and a new one is written in the same change.
- When a check comes to carry the decision, the file is deleted.
