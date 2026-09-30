# Lyngon devkit

The shared foundation for Lyngon software development: a Claude Code plugin marketplace (`plugins/`, one plugin per concern, in-house and vendored skills; pinned plugins recorded in `catalog/`), the shared devenv module (`devenv/`), and the convention documents behind both (`shared/`).
Purpose, audiences, done and non-goals are in [INTENT.md](INTENT.md).
How to use and contribute is in [README.md](README.md).
Terms are in [CONCEPTS.md](CONCEPTS.md).
Decisions are in [docs/adr/](docs/adr/).

This repository ships the Lyngon conventions and is also developed under them; keep the two apart.
What it ships (`shared/`, `devenv/` and every plugin outside the `devkit` category) is written for any Lyngon repository and never assumes this repository's layout or rules.
The rules for developing this repository itself live in this file and `docs/conventions/`, and apply nowhere else.
The shipped conventions apply here too, except where this file says otherwise.
Before adding or changing a rule, decide which of the two it belongs to.

## Checks

The `repo` plugin's hooks export the devenv environment into the agent session and refresh it when the devenv files change, so run commands directly, without a `devenv shell --` wrapper.

```sh
devenv test
```

`devenv test` runs every git hook on every file, then `validate-marketplace`, `validate-prerequisites` and the fixture tests of the validators.
It prints task names and times, and hook output only when a hook fails.
`DEVENV_NO_AI_AGENT=1` restores devenv's normal output, which shows no more of the hooks.
Per-hook results come from prek, run inside the devenv shell:

```sh
prek run --all-files
```

The validator encodes this repository's rules; read [scripts/validate-marketplace.sh](scripts/validate-marketplace.sh) before changing the layout.

## Layout

- `plugins/<concern>/`: one plugin per concern, each with `.claude-plugin/plugin.json`, `CHANGELOG.md` and `skills/<skill>/SKILL.md`.
- `plugins/<concern>/skills/<skill>/UPSTREAM.md`: marks a vendored skill, next to its upstream `LICENSE`. Every change to a vendored skill is listed under its "Local patches". Template in `catalog/UPSTREAM-TEMPLATE.md`.
- `catalog/<plugin>.md`: provenance record for each pinned third-party plugin. Template in `catalog/TEMPLATE.md`.
- `shared/`: convention documents used by more than one plugin, symlinked from the plugins. `STRUCTURE.md` there defines the layout of every Lyngon repository; this repository is the one exception to it. Edit them here; never edit through a symlink target inside a plugin.
- `devenv/`: the shared devenv module (`lyngon.enable`) that every Lyngon repository imports as `lyngon/devenv`. This repository imports it as `./devenv`, so `devenv test` here tests the module. Every value in it must be a `mkDefault` so consumers can override with a reason.
- `docs/adr/NNNN-slug.md`: decisions about this repository.
- `docs/conventions/<topic>.md`: conventions specific to this repository that need more than a line.
- `docs/TODO.md`: deferred work, only items the owner explicitly deferred.
- `docs/seed-prompts/<slug>.md`: a self-contained prompt that starts a fresh session on one queued item of `docs/TODO.md`; removed with the entry when the work lands.
  It says how to start (the skill to invoke, or "a bounded change: no design file and no plan file"), names the branch, and ends with "Remove this file and its `docs/TODO.md` entry in the last commit".
  Commits, the full check and the pull request follow the conventions and are not repeated in it.
- `docs/plans/<date>-<slug>.md`: the design and task plan of work in progress, committed on its branch and removed by `/build:finish` before it pushes the branch (ADR 0016).
- `tmp/`: agent scratch output, gitignored, may be deleted at any time.
- `sandbox/`: human experiments, gitignored, may live for weeks. Do not write there unless asked.

## Conventions

- Plugin `version` lives in `plugin.json` only. Every commit with a user-visible change to a plugin bumps that plugin's version by the commit's own semver level and adds its own `CHANGELOG.md` entry, in the same commit.
- Marketplace entries for pinned plugins need a 40-character `sha` and a catalog record. Vendored skills need `UPSTREAM.md` with a 40-character upstream commit.
- Third-party skills enter through `/devkit:add-skill`, which applies `shared/SKILL-REVIEW.md` and refuses upstreams without a license (ADR 0010).
- Vendored skills are rewritten to Lyngon vocabulary (`CONCEPTS.md`, the layout in `shared/STRUCTURE.md`), not merged. Compare against upstream at bump time and carry changes over by hand.
- Plugins share documents only through symlinks into `shared/`, and behaviour only through `dependencies` in `plugin.json`. Never copy a file from one plugin into another.
- Every plugin README declares its prerequisites (`documents`, `workflow`, `baseline`, `structure`), and its text may name an undeclared one only under a conditional heading; `validate-prerequisites` checks it. Rules in [docs/conventions/prerequisites.md](docs/conventions/prerequisites.md).
- `plugins/all/` is a bundle with no skills: its `dependencies` must list every local plugin outside the marketplace categories `devkit` (plugins that maintain this repository, ADR 0011) and `bundle`. `plugins/core/` bundles the plugins whose prerequisites stop at `documents`. The validator checks both.
- A SKILL.md has frontmatter on line 1, a `description`, and a `name` equal to its directory.
  Skill bodies stay agent-neutral: no Claude-specific wording unless the feature is Claude-only.
- Long skill content goes into `references/` files next to the SKILL.md, linked by relative path.
- `.mcp.json` and `.pre-commit-config.yaml` are generated by devenv and gitignored. `.claude/settings.json` is committed and edited by hand.
- The example repository tree in `README.md` mirrors the file set in `plugins/repo/skills/init/references/repo-files.md` and `devenv.md`. Change them together; the tree never shows a file init does not write.
- The plugin table in `README.md` is generated by `scripts/render-plugin-list.sh` between two marker comments. Never edit between them; the hook regenerates the table and fails until it is staged.
- `CLAUDE.md` is the source file; `AGENTS.md` is a symlink to it. Edit this file.

## Documents

INTENT.md is why and for whom: product, audiences, done, failure, non-goals, horizon. It changes only when the purpose changes.
README.md is how to use: getting started, layout, contributing, license.
CLAUDE.md is how to work: checks, layout, conventions, what not to touch.
CONCEPTS.md is terms only, no implementation details.
A convention specific to this repository that needs more than a line goes in `docs/conventions/<topic>.md`, with a one-line pointer here; the directory is created when the first one exists.
Anything that fits two files goes in the one whose audience needs it first, and the other links to it.
Record a decision as an ADR only when it is hard to reverse, surprising without context, and the result of a real trade-off.
