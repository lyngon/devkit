# CONCEPTS.md format

`CONCEPTS.md` is the repository's glossary: the ubiquitous language of its domain or problem.

Single source in `shared/` of the Lyngon devkit marketplace; plugins symlink it.
A repository may override it with `docs/conventions/concepts.md`.

Format adapted from Matt Pocock's `domain-modeling` skill (<https://github.com/mattpocock/skills>, MIT), which calls the file `CONTEXT.md`.
The MIT license text is `shared/LICENSE-mattpocock`; the provenance record is `plugins/discover/skills/domain-model/UPSTREAM.md`.

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
- Keep definitions to one or two sentences. Define what it is, not what it does.
- Only terms specific to this repository's domain belong. General programming concepts (timeouts, error types, utility patterns) do not, even when used heavily. Before adding a term, ask: is this unique to this context, or a general programming concept?
- No implementation details. `CONCEPTS.md` is not a spec, a scratchpad, or a place for decisions. Decisions go in ADRs.
- Group terms under subheadings only when natural clusters emerge. A flat list is fine.
- Add a `## Relationships` section when the relationships between terms are not obvious from the definitions.

## Single context versus several

Default: one `CONCEPTS.md` at the repository root. This fits almost every repository.

When a repository holds several contexts, the package that owns each context gets its own `CONCEPTS.md`, and the root `CONCEPTS.md` becomes a map:

```md
# Concepts map

## Contexts

- [Ordering](ordering/CONCEPTS.md): receives and tracks customer orders
- [Billing](billing/CONCEPTS.md): invoices and payments

## Relationships

- **Ordering → Billing**: Ordering emits `OrderPlaced`; Billing consumes it.
```

How to tell which applies:

- A root `CONCEPTS.md` with a `## Contexts` section is a map; follow it to the per-context files.
- A root `CONCEPTS.md` with a `## Language` section is the single context.
- Neither exists: create the root file lazily when the first term is settled.

When several contexts exist, infer which one the current topic belongs to. If unclear, ask.
Create per-context files lazily, when the first context-specific term is settled, never speculatively.

### With the Lyngon structure

The package that owns a context is its core library, so the glossary is `libs/<ctx>/CONCEPTS.md`.
Adapters and apps of a context never get their own glossary; their terms belong to the core library.
