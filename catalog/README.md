# Catalog records

The provenance records of the catalog, of two kinds.

One file per **pinned** third-party plugin listed in [marketplace.json](../.claude-plugin/marketplace.json), `catalog/<plugin>.md`.
A pinned plugin has no directory in this repository, so its provenance record lives here.
Without a record, the validator rejects the marketplace entry.

One file per upstream that skills are **vendored** from, `catalog/vendored/<upstream>.md`.
It covers everything taken from that upstream at one commit: where each piece went, and the local patches and review notes of each destination.
`<upstream>` is a short name in kebab-case.
The upstream license is `shared/LICENSE-<upstream>`, linked under that name into the root of every plugin that holds text from the upstream.

## Adding a pinned plugin

Copy [TEMPLATE.md](TEMPLATE.md) to `catalog/<plugin-name>.md`, where `<plugin-name>` is the `name` in the marketplace entry.
Fill in every field.
The validator checks that the upstream commit in the record equals the `sha` in the marketplace entry.

## Adding vendored skills

Copy each upstream skill directory into `plugins/<concern>/skills/<name>/` and rewrite it to Lyngon vocabulary.
Write the record from [vendored/TEMPLATE.md](vendored/TEMPLATE.md), or add to the record the upstream already has, at the commit that record names.
Each piece gets a row in the table of what was taken, and every change to it a bullet under "Local patches", under its destination.
Put the upstream license in `shared/LICENSE-<upstream>` and link it into the root of each plugin that holds a destination.
The validator checks the record's header lines, that every destination in the table exists, that every plugin holding one has the license link, and that no skill directory holds a record or a license file of its own.

## Bumping

Pinned: update `sha` and `version` in the marketplace entry, review the upstream diff, update the record.
Vendored: everything taken from one upstream moves together.
Compare the upstream at the new commit with the recorded commit for every row of the record's table, decide which changes to carry over, apply them by hand, update the record.
Vendored skills are rewritten, not merged.
