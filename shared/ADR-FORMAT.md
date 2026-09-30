# ADR format

Single source in `shared/` of the Lyngon devkit marketplace; plugins symlink it.
A repository may override it with `docs/conventions/adr.md`.

Format adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT).
The MIT license text is `shared/LICENSE-mattpocock`; the provenance record is `plugins/discover/skills/domain-model/UPSTREAM.md`.

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
- `## Change log`: required once an accepted ADR is edited; see [Editing an accepted ADR](#editing-an-accepted-adr).

## Editing an accepted ADR

An ADR is accepted once it is on the default branch; edits on the branch that introduces it are part of writing it.
An accepted ADR records what was decided and why, and git keeps its original wording, so an edit is allowed only when someone who acted on the old text would act exactly the same way on the new text:

- aligning its terminology with `CONCEPTS.md`;
- fixing a typo or a broken link;
- adding a forward pointer, such as "See also ADR 0012", or a `Status:` line.

Anything that widens, narrows or reverses the decision, its reasons or its consequences is a new ADR, and the old one gets a `Status:` line or a forward pointer.

Every edit adds one line to a `## Change log` section at the end of the ADR, which the first edit creates: the date and the nature of the change.

```md
## Change log

- 2026-10-02: "customer" became "client", matching `CONCEPTS.md`; added a pointer to ADR 0012.
```

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
