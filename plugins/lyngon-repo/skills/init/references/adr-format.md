# Architecture decision records

Format adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT).

ADRs live in `docs/adr/` with sequential numbering: `0001-slug.md`, `0002-slug.md`.
Package-local decisions live in `packages/<name>/docs/adr/` with their own numbering.
Scan the directory for the highest number and increment.

## Template

```md
# {Short title of the decision, stated as the decision}

{One to three sentences: context, what was decided, why.}
```

That is the whole ADR.
A single paragraph is a complete ADR; the value is in recording that the decision was made and why.

## Optional sections

Only when they add something a reader would otherwise miss:

- `## Considered options`: when the rejected alternatives are worth remembering, so nobody proposes them again in six months.
- `## Consequences`: when non-obvious downstream effects need calling out.
- A `Status:` line (`proposed`, `accepted`, `deprecated`, `superseded by 0007`) when a decision has been revisited. Omit it otherwise.

## When to write one

All three must be true:

1. **Hard to reverse.** Changing it later costs real effort.
2. **Surprising without context.** A future reader would look at the code and wonder why.
3. **A real trade-off.** There were genuine alternatives and one was picked for specific reasons.

If any is missing, skip it.
Easy-to-reverse decisions get reversed; unsurprising ones need no explanation; decisions with no alternative are just the obvious thing.

## What typically qualifies during initialization

- Architectural shape: monorepo, event sourcing, a chosen boundary between packages.
- Technology choices with lock-in: database, message bus, auth provider, deployment target. Not every library.
- Deliberate deviations from the obvious path.
- Constraints not visible in the code: compliance, contracts, platforms.
- Rejected alternatives when the rejection is non-obvious.

What does not qualify: the license, the git host, the package layout (that is a convention, not a decision), and the choice of devenv (organization-wide, already decided).
