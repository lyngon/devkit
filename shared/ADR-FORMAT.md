# ADR format

Single source in `shared/` of the Lyngon devkit marketplace; plugins symlink it.
A repository may override it with `docs/conventions/adr.md`.

Format adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT).

ADRs live in `docs/adr/` with sequential numbering: `0001-slug.md`, `0002-slug.md`.
Package-local decisions live in the package's own `docs/adr/` with their own numbering.
Scan the directory for the highest number and increment.
Create the directory lazily, when the first ADR is needed.

## Template

```md
# {Short title, stated as the decision}

{One to three sentences: context, what was decided, why.}
```

That is the whole ADR.
A single paragraph is a complete ADR; the value is in recording that the decision was made and why, not in filling out sections.

## Optional sections

Only when they add something a reader would otherwise miss.
Most ADRs need none.

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

## What qualifies

- Architectural shape: monorepo, event sourcing, a chosen boundary between packages.
- Integration patterns between contexts: events versus synchronous calls.
- Technology choices with lock-in: database, message bus, auth provider, deployment target. Not every library, just the ones that would take a quarter to swap.
- Boundary and scope decisions. The explicit no-s are as valuable as the yes-s.
- Deliberate deviations from the obvious path. These stop the next engineer from "fixing" something that was deliberate.
- Constraints not visible in the code: compliance, contracts, platforms, response-time budgets.
- Rejected alternatives when the rejection is non-obvious.

What does not qualify during repository setup: the license and the git host.

### With the Lyngon structure

The package layout does not qualify either; it is organization-wide, defined in `STRUCTURE.md`.
A context's decisions live in its core library, `libs/<ctx>/docs/adr/`.

### With the Lyngon baseline

The choice of devenv and the baseline does not qualify; it is organization-wide and already decided.
