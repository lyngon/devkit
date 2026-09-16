# Mixed vendoring policy with mandatory SHA for pinned entries

Status: superseded by 0006

Third-party plugins can be listed by pointing at upstream (pinned) or by copying the files in (vendored).
Pinning with a 40-character `sha` is deterministic and keeps upstream authorship and license intact, but it cannot take a subset of a plugin, cannot carry a local patch, and a bump shows up in review as a hash change with no visible diff.
Vendoring gives reviewable diffs, subsets and patches at the cost of a manual bump step.

We allow both, with a rule instead of a default: **pin** when the upstream plugin is used whole and unmodified, **vendor** when only some skills are wanted or a local patch is needed.
Every entry of either kind needs a catalog record, and the validator rejects any non-local source without a `sha`, so the marketplace can never list something nobody read at a known commit.

## Considered options

- Vendor everything: honest and reviewable, but pays the copy cost even for plugins used unchanged.
- Pin everything: no copies, but no subsets and no patches, and review of bumps happens upstream instead of in this repository.
