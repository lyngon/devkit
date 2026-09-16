# Vendored skills are rewritten to Lyngon vocabulary, not merged from upstream

A vendored skill copied verbatim could be updated by merging upstream diffs, but every Lyngon repository uses `CONCEPTS.md`, `packages/`, `INTENT.md` and one-sentence-per-line Markdown, and skill names are chosen for the plugin they live in (`interview`, `domain-model`, `approach` instead of `grilling`, `domain-modeling`, `grill-with-docs`).
We rewrite vendored skills freely and give up merging: a bump compares the upstream skill between the commit recorded in `UPSTREAM.md` and the new one, and a person or an agent carries the relevant changes over by hand.
Every deviation from upstream is listed under "Local patches" in `UPSTREAM.md` so the comparison has a starting point.

## Consequences

- Format documents that two plugins need (`CONCEPTS-FORMAT.md`, `ADR-FORMAT.md`) exist as byte-identical copies, since plugins cannot share files; the validator checks the copies.
- Upstream trigger phrases ("grill me") are kept in skill descriptions so muscle memory from upstream still works.
- The comparison flow is manual until the skill in `docs/TODO.md` exists.
