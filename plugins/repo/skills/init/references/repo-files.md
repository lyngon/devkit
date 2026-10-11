# Repository files

Templates and rules for the files the skill writes.
Replace every `{placeholder}`.
Do not leave template comments in generated files.

## What each document holds

The rules for the documents below are in the `conventions:documents` skill; invoke it before writing them.
This file holds the templates.

## INTENT.md

Written from the round 1 answers only.
Every section below is required.
Write no `## Priorities` section, whatever the interview said about priorities: it starts absent.

```md
# Intent

What this repository is for, for whom, and what done means.
It changes when the purpose changes, not when the plan changes.

## Product

**{Product name}** {one or two sentences: what it is and the problem it solves}.

## For whom

- Repository: {who reads and changes the repository}.
- Artifacts: {who consumes what it produces}.

## Done means

- {Two to four observable outcomes that mean the repository succeeded.}

## Failure means

- {The failure-in-a-year answer, as two to four observable outcomes.}

## Non-goals

- {Each non-goal from the interview, one line.}

## Horizon

{Throwaway, months, or years}. {One sentence on why.}
```

## .claude/CLAUDE.md

Init writes one line:

```md
@../INTENT.md
```

It imports the intent into every session, so the line stays whatever the authors add below it later.
Write no `CLAUDE.md` at the root and no `AGENTS.md`.

## .claude/rules/

One file per repository principle that the interview settled.
Most repositories start with none: the organization's principles come from the `principles` plugin, and whatever a tool can decide becomes a hook in `devenv.nix` instead.

```md
---
paths:
  - "{glob of the files the principle concerns}"
---

# {The principle's name, in words}

{The statement, in one or two sentences.}

Why: {one sentence}.
```

Leave the frontmatter out when the principle concerns the whole repository.

## README.md

````md
# {Repository name}

{One paragraph: what it is.}

## Intent

What this repository is for, for whom, and what done means is in [INTENT.md](INTENT.md).

## Layout

```text
apps/{name}/       {one line}
libs/{name}/       {one line}
docs/decisions/    decisions the code cannot show
```

Packages are laid out by kind; see the Lyngon devkit's `STRUCTURE.md` for the rules.

## Getting started

Every tool comes from the devenv shell.

```sh
devenv allow
devenv shell
```

Automatic activation: either `direnv allow` (uses `.envrc`), or add `eval "$(devenv hook zsh)"` to your shell configuration and skip direnv.
The VS Code extension `mkhl.direnv` loads the same environment into the editor, but the Claude Code extension keeps the environment it started with.
The `repo` plugin's hooks export the current environment into each agent session and refresh it when the devenv files change.

Run every check the way CI does:

```sh
devenv test
```

Claude Code registers the `lyngon` plugin marketplace from `.claude/settings.json` when you trust the folder.
The settings name every plugin; install them with:

```sh
claude plugin install all@lyngon --scope project
```

{When the settings enable `core` or a subset instead of `all`, the block installs those plugins by name and `conventions@lyngon`, each with `--scope project`.}

{Per-artifact usage or delivery instructions, from the delivery question.}

## Contributing

{Branching and review expectations if stated; otherwise omit the section.}

## License

{SPDX name}. See [LICENSE](LICENSE).
````

Write a `LICENSE` file only when the interview settled a license.
Do not pick one on the user's behalf.

## docs/TODO.md

Only when the user explicitly deferred something.

```md
# TODO

Deferred work the owner explicitly chose not to do yet.
One item per line, with the date it was deferred.

- {YYYY-MM-DD}: {item}
```

## .claude/settings.json

Committed, hand-maintained.
Registers the marketplace, which Claude Code adds for colleagues once they trust the folder, and enables every plugin the repository uses by name: `all@lyngon` and each of its members, unless the user chose `core@lyngon` or a subset, which is enabled the same way with every plugin it depends on, and with `conventions@lyngon`, since every repository this skill sets up adopts the Lyngon workflow.
Claude Code installs a bundle's members as dependencies but does not count them as enabled when it checks a member's own dependencies, so with the bundle alone `build` fails to load for want of `practice` and `review` (seen in Claude Code 2.1.278).
Plugins are not installed for colleagues automatically (Claude Code 2.1.195 and later); Claude Code shows them the install command, and the README repeats it.
The README's install commands name the bundle, or the chosen plugins, and `conventions`; they do not enumerate a bundle's members, which only these settings do.
The key under `extraKnownMarketplaces` must equal the marketplace manifest name (`lyngon`): Claude Code registers under the manifest name and the `@marketplace` suffixes in `enabledPlugins` must match it. Project marketplaces are applied once per Claude Code process start, after the folder is trusted.
`attribution.commit` is empty because the Lyngon conventions never name an agent as co-author: without it, Claude Code tells every session and subagent that commits to add its `Co-Authored-By` trailer, and each one has to weigh that against the rule (Claude Code 2.0.62 and later read this key).

```json
{
  "attribution": {
    "commit": ""
  },
  "extraKnownMarketplaces": {
    "lyngon": {
      "source": {
        "source": "github",
        "repo": "lyngon/devkit"
      }
    }
  },
  "enabledPlugins": {
    "all@lyngon": true,
    "repo@lyngon": true,
    "discover@lyngon": true,
    "build@lyngon": true,
    "practice@lyngon": true,
    "review@lyngon": true,
    "writing@lyngon": true,
    "conventions@lyngon": true,
    "principles@lyngon": true
  }
}
```

## .vscode/extensions.json

```json
{
  "recommendations": ["mkhl.direnv"]
}
```

## .gitignore baseline

Always present, before the stack-specific patterns from `devenv.md`:

```gitignore
# Agent scratch output. May be deleted at any time.
/tmp/
# Human experiments. May live for weeks, never committed.
/sandbox/

# devenv (generated or per-user)
.devenv*
devenv.local.nix
devenv.local.yaml
.pre-commit-config.yaml
.mcp.json

# direnv
.direnv/

# Claude Code per-user overrides (.claude/settings.json is committed)
.claude/settings.local.json

# Editors and OS
.DS_Store
.idea/
.vscode/*
!.vscode/extensions.json
```

## CI

GitHub Actions default; mirror the same steps for another host.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v16
        with:
          name: devenv
      - name: Install devenv
        run: nix profile add nixpkgs#devenv
      - name: Run git hooks and tests
        run: devenv test
```

Add delivery jobs (image build, package publish) only for artifacts whose delivery the user named, as separate jobs that depend on `test`.

## Packages

Every package named in the interview is created with the `add-package` skill of this plugin, one invocation per package, core libraries first.
It decides the directory from the kind, creates the manifest with the stack's own initializer, writes `devenv.nix`, `README.md` and, for a package the interview gave an intent of its own, `INTENT.md`, and registers the package in its workspace and the root `devenv.yaml`.
The root workspace files are written before the first package of each language; their templates are in `add-package`'s `workspaces.md` reference.
