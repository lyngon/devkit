# devenv generates `.mcp.json`; `.claude/settings.json` is committed by hand

devenv's `claude.code` module can generate `.claude/settings.json`, but only from a fixed set of keys (hooks, permissions, model, env), with no option for a key such as `extraKnownMarketplaces`, and a second definition of the same file is silently dropped (verified against devenv 2.3.1).
The baseline therefore leaves the module off.
devenv writes only `.mcp.json`, through its generic `files` option and only in a repository that sets `lyngon.mcp.enable = true`, and that file is gitignored, while `.claude/settings.json` is a committed file edited by hand that registers the marketplace and enables plugins.

## Consequences

- Two files, two owners: turning the MCP server on or changing it goes in `devenv.nix`, a change to plugins or permissions in `.claude/settings.json`.
- The key under `extraKnownMarketplaces` and the `@marketplace` suffixes in `enabledPlugins` must equal the marketplace's manifest name, because Claude Code registers the marketplace under that name (verified 2026-09-16 with Claude Code 2.1.268).
- Once the module passes arbitrary settings through, the decision is worth making again.

Enforced by: judgment
