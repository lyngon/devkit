# Lyngon devkit

The shared foundation for software development at Lyngon: the reusable pieces a repository needs to work the Lyngon way.

The Lyngon way is opinionated, and this repository exists to make those opinions cheap to follow and hard to drift from.
Every tool comes from devenv and Nix, never from a global install.
A repository that adopts the structure is laid out by package kind (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`), even with one package, and a package is created with a skill, never by hand.
The same git hooks run everywhere and are never disabled to make a commit pass.
INTENT.md, CLAUDE.md, CONCEPTS.md and ADRs carry purpose, working rules, terms and decisions, in that division and no other.
Every third-party skill was read by a named person at a recorded commit before it got in.
A repository can override a baseline value with a comment saying why; it cannot opt out of the baseline.

The pieces:

- A Claude Code plugin marketplace: one plugin per concern, with in-house skills and vendored third-party skills side by side, plus pinned third-party plugins. Everything third-party was read by a named person at a recorded commit.
- The shared devenv module (`lyngon/devenv`) that gives every repository the same git hooks, MCP server file and languages.
- The convention documents behind both, in `shared/`.

Other kinds of reusable pieces may join; the test is that they are used by more than one repository.

## Intent

What this repository is for, for whom, and what done means is in [INTENT.md](INTENT.md).

## Layout

```text
.
├── .claude-plugin/
│   └── marketplace.json    the marketplace manifest
├── plugins/
│   ├── all/                the bundle every Lyngon repository installs
│   └── <concern>/          one plugin per concern, in-house and vendored skills side by side
│       ├── .claude-plugin/plugin.json
│       ├── CHANGELOG.md
│       └── skills/<name>/  a skill; vendored ones carry UPSTREAM.md and the upstream LICENSE
├── catalog/
│   └── <plugin>.md         provenance record for every pinned third-party plugin
├── shared/                 convention documents, symlinked into the plugins that use them
├── devenv/                 the shared devenv module every Lyngon repository imports
├── scripts/                validation and generation run by git hooks and CI
├── docs/
│   ├── adr/                decisions about this repository
│   └── TODO.md             deferred work
├── INTENT.md               what the repository is for, for whom, and what done means
├── CLAUDE.md               how to work here, for agents (AGENTS.md is a symlink to it)
└── CONCEPTS.md             the terms used in this repository
```

## Plugins

Generated from the marketplace manifest by `scripts/render-plugin-list.sh`; do not edit between the markers.

<!-- plugins:start -->
| Plugin | Skills | Prerequisites | Description |
| --- | --- | --- | --- |
| `all` | bundle of `repo`, `discover`, `writing`, `conventions` | documents, baseline, structure | Every plugin a Lyngon repository uses, installed with one command. A bundle: it has no skills of its own. |
| `core` | bundle of `discover`, `writing`, `conventions` | documents | The plugins that work in any repository with the Lyngon documents: discover, writing and conventions. A bundle: it has no skills of its own. |
| `repo` | `/repo:add-package`, `/repo:init` | documents, baseline, structure | Set up or adopt a repository to Lyngon conventions (interview, INTENT.md, CLAUDE.md, README, CONCEPTS.md, ADRs, devenv, git hooks) and create packages in the kind-first layout. |
| `discover` | `/discover:approach`, `/discover:domain-model`, `/discover:interview` | documents | Discovery before building: relentless interviews that sharpen a plan and write CONCEPTS.md terms and ADRs as they crystallise. |
| `devkit` | `/devkit:add-skill` | documents, baseline, structure | Maintain the Lyngon devkit itself: add third-party or new skills to the marketplace with vetting, provenance and placement by concern. |
| `writing` | `/writing:unslop` | git | Prose quality: edit documentation, READMEs, posts and other non-code text so it reads as written by a person. |
| `conventions` | `adr` (by path), `documents` (by path), `engineering` (by path), `markdown` (by path), `nix` (by path), `python` (by path), `typescript` (by path) | documents | Organization-wide conventions, loaded automatically by file path: engineering rules for every file, one skill per language, and the rules for Markdown, ADRs and the standard documents. |
| `skill-creator` | pinned, see [catalog/skill-creator.md](catalog/skill-creator.md) | git | Anthropic's skill authoring plugin: create, evaluate, improve and benchmark skills. Pinned; used by /devkit:add-skill to draft new in-house skills. |
<!-- plugins:end -->

## What a Lyngon repository looks like

A repository that adopts the structure is laid out by package kind, as defined in [shared/STRUCTURE.md](shared/STRUCTURE.md): entrypoints under `apps/`, libraries under `libs/`, cross-language interfaces under `contracts/`, repository-internal executables under `tools/`, and everything that references a deployable by coordinates under `infra/`.
Language is never a path segment.
A directory appears with its first package, so a one-package repository has `apps/<name>/` alone.
This is what `/repo:init` and `/repo:add-package` produce; the names are examples for one context, `orders`.

```text
my-service/
├── apps/
│   └── orders-api/             Python entrypoint: main, wiring, config; delivered as an image
│       ├── devenv.nix          tasks, hooks and processes for this package only
│       ├── INTENT.md           why it exists and for whom
│       ├── README.md           what it is, how to run it
│       ├── CLAUDE.md           how to work here (AGENTS.md is a symlink to it)
│       └── docs/adr/           decisions local to this package
├── libs/
│   ├── orders/                 core library: domain and application; holds CONCEPTS.md
│   └── orders-postgres/        one adapter per technology
├── contracts/
│   └── orders-api/             schema, one generated library per language, conformance/
├── infra/
│   ├── modules/orders-api/     how the deployable is instantiated
│   └── environments/prod/      one root per environment, never a branch
├── docs/
│   ├── adr/                    decisions about the whole repository
│   ├── conventions/            repository-specific conventions too long for a CLAUDE.md line
│   └── TODO.md                 work the owner explicitly deferred
├── .claude/settings.json       registers the lyngon marketplace, enables all@lyngon
├── .github/workflows/ci.yml    runs devenv test
├── .vscode/extensions.json     recommends the direnv extension
├── .envrc                      loads the devenv shell through direnv
├── pyproject.toml              the Python workspace: explicit members, one uv.lock
├── ruff.toml                   every stable ruff rule, each ignore with its reason
├── devenv.yaml                 imports lyngon/devenv and every package's devenv.nix
├── devenv.nix                  lyngon.enable and lyngon.structure.enable, languages, hooks and tasks
├── secretspec.toml             declared secrets; values never enter the repository
├── INTENT.md                   why and for whom
├── CLAUDE.md                   how to work (AGENTS.md is a symlink to it)
├── CONCEPTS.md                 the terms
└── README.md                   how to use
```

And the way of working in it, in the order things happen:

- `/repo:init` once, to set the repository up or bring an existing one onto the baseline; it asks which prerequisites the repository adopts and writes only those.
- `/repo:add-package` whenever a package is needed; it decides the directory from the package kind, writes the package files and registers the package in its workspace. Agents invoke it on their own.
- `/discover:approach` before building anything that has more than one reasonable design; terms land in CONCEPTS.md and decisions in ADRs as they settle.
- An ADR only for a decision that is hard to reverse, surprising without context, and the result of a real trade-off.
- Conventions load on their own by file path from the `conventions` plugin: engineering rules for every file, one skill per language, and the rules for Markdown, ADRs and the standard documents. Nothing is copied into the repository.
- `/writing:unslop` before any prose is handed over.
- `devenv test` before every commit; it runs every git hook on every file, and no hook is ever disabled to make it pass.

## Installing the plugins

For yourself, in Claude Code:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon
```

`all` is a bundle that brings every plugin a Lyngon repository uses, see the table above.
A repository that keeps its own toolchain and layout installs `core` instead, which brings `discover`, `writing` and `conventions` and needs only the Lyngon documents:

```sh
claude plugin install core@lyngon
```

The Prerequisites column says what each plugin needs from a repository; the rules are in [docs/conventions/prerequisites.md](docs/conventions/prerequisites.md).
For a subset, install the members by name instead; `repo` brings `discover` with it as a dependency:

```sh
claude plugin install repo@lyngon
claude plugin install writing@lyngon
```

## Adopting a repository

The steps are the same for an empty repository and for one that has grown organically; `/repo:init` tells them apart by the tracked files.

1. Install the plugins as above, at least `repo`.
2. Open Claude Code in the repository and run `/repo:init`.
   It interviews you, then writes INTENT.md, CLAUDE.md, README.md, CONCEPTS.md, ADRs, devenv with the shared module imported, git hooks, CI, every package you named, and a `.claude/settings.json` that registers the marketplace and enables `all@lyngon`, or the subset you chose.
3. Commit.

In an existing repository, init shows a diff for every file it would touch, merges into an existing README.md and CLAUDE.md instead of replacing them, and asks before reversing an AGENTS.md symlink.

Colleagues who clone the repository get the marketplace registered as soon as they trust the folder.
Plugins are not installed for them automatically (Claude Code 2.1.195 and later); Claude Code reports them as not installed and shows the command, which with the bundle is one:

```sh
claude plugin install all@lyngon
```

To add a plugin to an adopted repository later, `--scope project` writes it into the committed settings:

```sh
claude plugin install writing@lyngon --scope project
```

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
5. Add it to the `dependencies` of `plugins/all/`, unless its marketplace category is `devkit`.
6. Run `devenv test`; it regenerates the plugin table above and fails until the change is staged.

## Adding third-party work

Run `/devkit:add-skill <name, URL or description>` from a Claude Code session in this repository; it finds, vets and installs, and refuses upstreams without a license.
By hand, the same policy: read every skill, command, agent and hook you are about to take, then pick one of two kinds, see [ADR 0006](docs/adr/0006-plugins-by-concern-pin-per-plugin-vendor-per-skill.md):

- **Pin the plugin** when the upstream plugin is used whole and unmodified: add a marketplace entry with a 40-character `sha` and a `version`, and a record in `catalog/<name>.md`.
- **Vendor the skill** when only some skills are wanted or they must be rewritten to Lyngon vocabulary: copy the skill into the plugin for its concern, with the upstream `LICENSE` and an `UPSTREAM.md` beside `SKILL.md`.

See [catalog/README.md](catalog/README.md) for both.

## License

Apache-2.0 for everything Lyngon wrote.
Vendored skills keep their upstream license, next to their files.
