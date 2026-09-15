# CONCEPTS.md

`CONCEPTS.md` is the repository's glossary: the ubiquitous language of its domain or problem.
The format is adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT), which calls the file `CONTEXT.md`.
Lyngon repositories call it `CONCEPTS.md`.
If an existing repository has a `CONTEXT.md`, propose renaming it and ask.

## During the interview

- **Challenge against the glossary.** When the user uses a term that conflicts with an existing definition, say so immediately and ask which meaning is right.
- **Sharpen fuzzy language.** When a word is vague or overloaded ("account", "job", "config"), propose a precise canonical term and list the alternatives to avoid.
- **Probe with scenarios.** When two concepts seem close, invent a concrete edge case that forces a boundary between them.
- **Write entries as they settle.** Draft the entry in the round where the term is agreed. Do not batch them for the end.

## Structure

```md
# {Repository or context name}

{One or two sentences on what this context is and why it exists.}

## Language

**Order**:
{One or two sentences. What it is, not what it does.}
_Avoid_: Purchase, transaction

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account

## Relationships

- A **Customer** places many **Orders**.
```

## Rules

- Be opinionated. When several words exist for one concept, pick the best and list the rest under `_Avoid_`.
- Keep definitions to one or two sentences.
- Only terms specific to this repository's domain belong. General programming concepts do not, even when used heavily.
- No implementation details. `CONCEPTS.md` is not a spec, a scratchpad, or a place for decisions. Decisions go in ADRs.
- Group terms under subheadings only when natural clusters emerge.
- Add a `## Relationships` section when the relationships between terms are not obvious from the definitions.

## Monorepo layout

Default: one `CONCEPTS.md` at the repository root.

When packages have genuinely different domains, each package gets its own `packages/<name>/CONCEPTS.md`, and the root `CONCEPTS.md` becomes a map:

```md
# Concepts map

## Contexts

- [Ordering](packages/ordering/CONCEPTS.md): receives and tracks customer orders
- [Billing](packages/billing/CONCEPTS.md): invoices and payments

## Relationships

- **Ordering → Billing**: Ordering emits `OrderPlaced`; Billing consumes it.
```

Create per-package files lazily, when the first package-specific term is settled, never speculatively.
