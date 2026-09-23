---
name: adr
description: Lyngon conventions for architecture decision records under docs/adr/. Background knowledge, loaded automatically while working on an ADR.
user-invocable: false
paths:
  - "**/docs/adr/*.md"
---

# ADR conventions

Format and rules are in [ADR-FORMAT.md](ADR-FORMAT.md); this is the short form.

- Write one only when all three hold: hard to reverse, surprising without context, the result of a real trade-off. If one is missing, it is not an ADR.
- The title is the decision, stated as a sentence: "Vendored skills are rewritten, not merged".
- One to three sentences of context, decision and why is a complete ADR. Add `## Considered options` only when the rejected alternatives must not be proposed again, `## Consequences` only for effects a reader would miss.
- Numbering is sequential per directory: the next number after the highest present. Repository-wide decisions in `docs/adr/`, a package's decisions in its own `docs/adr/`.
- An accepted ADR is never rewritten. A change of mind is a new ADR, and the old one gets a `Status: superseded by NNNN` line.
- Say what was rejected and why when the rejection is not obvious; the explicit no is as valuable as the yes.

## With devenv

Checked by the `markdownlint` and `prose-lint` hooks.
The choice of devenv is organization-wide and gets no ADR in a repository.

## With the Lyngon structure

A context's decisions live in its core library's `docs/adr/`.
The layout is organization-wide and gets no ADR in a repository.
