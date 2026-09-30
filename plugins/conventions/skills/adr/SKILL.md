---
name: adr
description: Lyngon conventions for architecture decision records under docs/adr/. Invoke before writing or editing an ADR.
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
- An ADR is accepted once it is on the default branch. An edit to an accepted ADR is allowed only when someone who acted on the old text would act the same way on the new one: terminology aligned with `CONCEPTS.md`, a typo, a broken link, a forward pointer, a `Status:` line. A change of mind (anything that widens, narrows or reverses the decision, its reasons or its consequences) is a new ADR, and the old one gets a `Status: superseded by NNNN` line or a forward pointer.
- Every edit to an accepted ADR adds a dated line saying what changed to a `## Change log` section at its end, which the first edit creates.
- Say what was rejected and why when the rejection is not obvious; the explicit no is as valuable as the yes.

## With the Lyngon baseline

Checked by the `markdownlint` and `prose-lint` hooks.
The choice of devenv and the baseline is organization-wide and gets no ADR in a repository.

## With the Lyngon structure

A context's decisions live in its core library's `docs/adr/`.
The layout is organization-wide and gets no ADR in a repository.
