# One plugin per concern

A Claude Code plugin is the unit of installation, so putting every in-house skill into a single `lyngon` plugin would force every repository to install skills it does not use, and would give all skills one shared version number.
We split in-house skills into one plugin per concern (`repo`, `discover`, and so on), each with its own `plugin.json` version and `CHANGELOG.md`.
The cost is more manifests to maintain and a longer plugin list in the marketplace.
