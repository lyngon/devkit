# devenv generates `.mcp.json`; `.claude/settings.json` is committed by hand

devenv's `claude.code` module can generate `.claude/settings.json`, but only from a fixed set of keys (hooks, permissions, model, env).
It has no option for arbitrary keys such as `extraKnownMarketplaces`, and a second definition of the same file is silently dropped (verified against devenv 2.3.1).
Since this repository wires no Claude Code hooks, the module would produce a file containing only `"hooks": {}`.

We therefore do not enable the module.
devenv writes only `.mcp.json` through its generic `files` option, so the devenv MCP server is configured from `devenv.nix` and the file is gitignored.
`.claude/settings.json` is a committed, hand-maintained file that registers the marketplace and enables plugins.

## Consequences

- Two files, two owners. A change to the MCP server goes in `devenv.nix`; a change to plugins or permissions goes in `.claude/settings.json`.
- A contributor without devenv still gets the marketplace registration, but not the MCP server.
- The key under `extraKnownMarketplaces` is cosmetic: Claude Code registers the marketplace under its manifest name, so the key and the `@marketplace` suffixes in `enabledPlugins` must equal that name (verified 2026-09-16 with Claude Code 2.1.268).
- If the module later gains a settings passthrough, this decision should be revisited.
