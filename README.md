# Lyngon skills

Lyngon's Claude Code plugin marketplace.
It holds the plugins Lyngon writes and a catalog of third-party plugins that someone at Lyngon has read and pinned.

## Intent

What this repository is for, for whom, and what done means is in [INTENT.md](INTENT.md).

## Layout

```text
.claude-plugin/marketplace.json   the marketplace manifest
plugins/<name>/                   in-house plugins, one per concern
plugins/third-party/<name>/       vendored third-party plugins, with their upstream license
catalog/<name>.md                 vetting record for every third-party plugin
docs/adr/                         decisions about this repository
docs/TODO.md                      deferred work
scripts/                          validation run by git hooks and CI
INTENT.md                         what the repository is for, for whom, and what done means
CLAUDE.md                         context for agents (AGENTS.md is a symlink to it)
CONCEPTS.md                       the terms used in this repository
```

## Using the marketplace

```sh
claude plugin marketplace add lyngon/skills
claude plugin install lyngon-repo@lyngon
```

Repositories set up with `/lyngon-repo:init` register the marketplace in their committed `.claude/settings.json`, so colleagues get it without these commands.

## Developing

Every tool comes from the devenv shell.

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

This repository registers itself as the marketplace `lyngon-dev` in `.claude/settings.json`, so a Claude Code session opened here loads the plugins from the working tree.

## Adding an in-house plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version`, `description` and `license`.
2. Add skills under `plugins/<name>/skills/<skill>/SKILL.md`.
3. Add `plugins/<name>/CHANGELOG.md`.
4. Add an entry to `.claude-plugin/marketplace.json` without a `version` field; the version lives in `plugin.json`.
5. Run `devenv test`.

## Adding a third-party plugin

Read every skill, command, agent and hook you are about to list.
Then pick one of two kinds, see [ADR 0002](docs/adr/0002-mixed-vendoring-policy-with-mandatory-sha.md):

- **Pinned** when the upstream plugin is used whole and unmodified: add a marketplace entry with a 40-character `sha` and a `version`.
- **Vendored** when only some skills are wanted or a local patch is needed: copy the files into `plugins/third-party/<name>/` with the upstream license file.

Both kinds need a record in `catalog/<name>.md`, see [catalog/README.md](catalog/README.md).

## License

Apache-2.0 for everything Lyngon wrote.
Vendored plugins keep their own license, next to their files.
