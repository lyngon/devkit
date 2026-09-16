# Lyngon devkit

The shared foundation for software development at Lyngon: the reusable pieces a repository needs to work the Lyngon way.

- A Claude Code plugin marketplace: one plugin per concern, with in-house skills and vendored third-party skills side by side, plus pinned third-party plugins. Everything third-party was read by a named person at a recorded commit.
- The shared devenv module (`lyngon/devenv`) that gives every repository the same git hooks, MCP server file and languages.
- The convention documents behind both, in `shared/`.

Other kinds of reusable pieces may join; the test is that they are used by more than one repository.

## Intent

What this repository is for, for whom, and what done means is in [INTENT.md](INTENT.md).

## Layout

```text
.claude-plugin/marketplace.json   the marketplace manifest
plugins/<concern>/                one plugin per concern, holding in-house and vendored skills
plugins/<concern>/skills/<name>/  a skill; vendored ones carry UPSTREAM.md and the upstream LICENSE
catalog/<plugin>.md               provenance record for every pinned third-party plugin
docs/adr/                         decisions about this repository
docs/TODO.md                      deferred work
scripts/                          validation run by git hooks and CI
shared/                           convention documents symlinked into plugins
devenv/                           the shared devenv module every Lyngon repository imports
INTENT.md                         what the repository is for, for whom, and what done means
CLAUDE.md                         context for agents (AGENTS.md is a symlink to it)
CONCEPTS.md                       the terms used in this repository
```

## Using the marketplace

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install repo@lyngon
claude plugin install discover@lyngon
```

Repositories set up with `/repo:init` register the marketplace in their committed `.claude/settings.json`, so colleagues get it without these commands.

## Developing

Every tool comes from the devenv shell.
The shell is built from `devenv/`, the same baseline module other Lyngon repositories import (see `devenv/devenv.nix` for the consumer snippet).

```sh
devenv allow
devenv shell
```

Automatic activation: either `direnv allow` (uses `.envrc`), or add `eval "$(devenv hook zsh)"` to your shell configuration and skip direnv.
The VS Code extension `mkhl.direnv` loads the same environment into the editor, which is what makes the tools available to the Claude Code extension.

Run every check the way CI does:

```sh
devenv test
```

This repository registers itself as the marketplace `lyngon` from the working tree in `.claude/settings.json`, so a Claude Code session opened here installs the plugins from this checkout. Project marketplaces are applied once per Claude Code process start, so a new registration needs a fresh session, not `/reload-plugins`.

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version`, `description` and `license`.
2. Add skills under `plugins/<name>/skills/<skill>/SKILL.md`.
3. Add `plugins/<name>/CHANGELOG.md`.
4. Add an entry to `.claude-plugin/marketplace.json` without a `version` field; the version lives in `plugin.json`.
5. Run `devenv test`.

## Adding third-party work

Run `/devkit:add-skill <name, URL or description>` from a Claude Code session in this repository; it finds, vets and installs, and refuses upstreams without a license.
By hand, the same policy: read every skill, command, agent and hook you are about to take, then pick one of two kinds, see [ADR 0006](docs/adr/0006-plugins-by-concern-pin-per-plugin-vendor-per-skill.md):

- **Pin the plugin** when the upstream plugin is used whole and unmodified: add a marketplace entry with a 40-character `sha` and a `version`, and a record in `catalog/<name>.md`.
- **Vendor the skill** when only some skills are wanted or they must be rewritten to Lyngon vocabulary: copy the skill into the plugin for its concern, with the upstream `LICENSE` and an `UPSTREAM.md` beside `SKILL.md`.

See [catalog/README.md](catalog/README.md) for both.

## License

Apache-2.0 for everything Lyngon wrote.
Vendored skills keep their upstream license, next to their files.
