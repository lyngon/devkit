# Catalog records

One file per **pinned** third-party plugin listed in [marketplace.json](../.claude-plugin/marketplace.json).
A pinned plugin has no directory in this repository, so its provenance record lives here.
Without a record, the validator rejects the marketplace entry.

**Vendored** skills are different: their provenance record is the `UPSTREAM.md` next to their `SKILL.md`, with the upstream license file beside it.
See [ADR 0006](../docs/adr/0006-plugins-by-concern-pin-per-plugin-vendor-per-skill.md).

## Adding a pinned plugin

Copy [TEMPLATE.md](TEMPLATE.md) to `catalog/<plugin-name>.md`, where `<plugin-name>` is the `name` in the marketplace entry.
Fill in every field.
The validator checks that the upstream commit in the record equals the `sha` in the marketplace entry.

## Adding a vendored skill

Copy the upstream skill directory into `plugins/<concern>/skills/<name>/`, add the upstream `LICENSE`, and write `UPSTREAM.md` from [UPSTREAM-TEMPLATE.md](UPSTREAM-TEMPLATE.md).
Rewrite the skill to Lyngon vocabulary and record every change under "Local patches".

## Bumping

Pinned: update `sha` and `version` in the marketplace entry, review the upstream diff, update the record.
Vendored: compare the upstream skill at the new commit with the recorded commit, decide which changes to carry over, apply them by hand, update `UPSTREAM.md`.
Vendored skills are rewritten, not merged.
