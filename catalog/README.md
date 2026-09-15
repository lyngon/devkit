# Catalog records

One file per third-party plugin listed in [marketplace.json](../.claude-plugin/marketplace.json).
The record is the evidence behind the word "vetted".
Without a record, the validator rejects the marketplace entry.

Two kinds of third-party entry exist (see [ADR 0002](../docs/adr/0002-mixed-vendoring-policy-with-mandatory-sha.md)):

- **Pinned**: the marketplace entry points at the upstream repository with a 40-character `sha`.
  Nothing is copied into this repository.
- **Vendored**: the plugin is copied into `plugins/third-party/<name>/` together with its upstream license file.

## Adding a record

Copy [TEMPLATE.md](TEMPLATE.md) to `catalog/<plugin-name>.md`, where `<plugin-name>` is the `name` in the marketplace entry.
Fill in every field.
The validator checks that the upstream commit in the record equals the `sha` in the marketplace entry for pinned plugins.

## Bumping

Pinned: update `sha` and `version` in the marketplace entry, review the upstream diff, update the record.
Vendored: copy the new upstream files over the old ones, review the diff in this repository, update the record.
