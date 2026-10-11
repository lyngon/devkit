# Vendored skills are rewritten, not merged

A vendored skill copied verbatim could be updated by merging upstream diffs, but every Lyngon repository uses `CONCEPTS.md`, `INTENT.md` and one-sentence-per-line Markdown, and a skill is named for the plugin it lives in (`interview`, `domain-model`, `approach` where upstream says `grilling`, `domain-modeling`, `grill-with-docs`).
We rewrite vendored skills freely and give up merging: a bump compares the upstream skill between the commit recorded in `UPSTREAM.md` and the new one, and a person or an agent carries the relevant changes over by hand.
Every deviation from upstream is listed under "Local patches" in `UPSTREAM.md`, so the comparison has a starting point.

## Consequences

- Upstream trigger phrases ("grill me") are kept in skill descriptions, so muscle memory from upstream still works.
- The comparison is manual until the skill for it in `docs/TODO.md` exists.

Enforced by: judgment
