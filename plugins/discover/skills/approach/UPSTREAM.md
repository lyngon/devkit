# approach

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream path**: `skills/engineering/grill-with-docs`
- **Upstream name**: `grill-with-docs`
- **Upstream version**: 1.2.3
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

The user-invoked entry point that combines `interview` and `domain-model`, so a design session writes its docs as it goes.

## Local patches

- Renamed `grill-with-docs` to `approach`.
- Skill calls are namespaced (`discover:interview`, `discover:domain-model`) so they resolve inside this plugin.
- Added the `--no-docs` argument, replacing upstream's separate `grill-me` skill.

## Review notes

Pure prompt text, no scripts, no hooks, no tool restrictions.
