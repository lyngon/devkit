# The `all` bundle is the install unit for repositories

Claude Code installs one plugin per `claude plugin install` and has no way to install every plugin of a marketplace (verified against the documentation and Claude Code 2.1.268).
Since 2.1.195 a committed `.claude/settings.json` adds the marketplace after folder trust but does not install plugins that come from an external source; every colleague runs the install command themselves.
With one command per plugin, adoption cost grows with the number of plugins, and every repository's `enabledPlugins` list drifts as plugins are added here.
Claude Code does install a plugin's `dependencies` with it (ADR 0008).

We therefore ship a content-free plugin, `all`, whose only purpose is its `dependencies`: every local plugin a Lyngon repository uses.
The validator requires `all` to list exactly the local plugins outside category `devkit`, so a new plugin cannot be added without joining the bundle.
Category `devkit` marks plugins that maintain this repository and are useless elsewhere.
`/repo:init` enables `all@lyngon` by default; a repository that wants a subset enables members directly.

## Consequences

- Adoption is two commands, `marketplace add` and `install all@lyngon`, whatever the number of plugins.
- A repository with `all` enabled cannot disable one member; Claude Code refuses to disable a dependency of an enabled plugin. Subsets are chosen at install time, not by disabling.
- Narrower bundles can be added the same way if the marketplace grows diverse; only `all` has the completeness rule.
- The validator accepts a plugin with dependencies and no components, and checks that every dependency of every local plugin is a marketplace entry.
- Pinned third-party plugins are not members; they are installed on their own where needed.
