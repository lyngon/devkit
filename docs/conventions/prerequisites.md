# Plugin prerequisites

What a plugin may assume about the repository it is installed in, how it declares that, and how the declaration is enforced.
Every plugin is usable in every repository that meets its declared prerequisites and nothing more.

## The prerequisites

| Prerequisite | The repository has | Test |
| --- | --- | --- |
| `git` | A git repository with Markdown in it. Every plugin may assume this; it is never declared. | Always true. |
| `documents` | The Lyngon document set, existing or created lazily: `CONCEPTS.md`, `docs/adr/`, `INTENT.md`, `CLAUDE.md` with `AGENTS.md` symlinked to it, `docs/TODO.md`, `docs/conventions/`. | The files may be created; they need not exist. |
| `baseline` | The repository imports `lyngon/devenv`, the Baseline: the named hooks, `lyngon.*` options and the MCP file. | `lyngon.enable = true` in `devenv.nix`. |
| `structure` | The repository follows `shared/STRUCTURE.md`. | The root `CLAUDE.md` says "This repository follows the Lyngon structure", and `lyngon.structure.enable = true` in `devenv.nix`. |

The three are independent, not a ladder.
A repository can have the documents without the baseline, or the baseline without the layout.
Using devenv at all is a condition, not a prerequisite: a repository can use devenv without the baseline, so generic devenv facts (tools come from `devenv.nix`, `devenv test`, `secretspec`) are conditional on devenv, and only `lyngon.*`, the `lyngon` input and the named hooks are baseline facts.
Claude Code itself is a devkit-wide assumption (see INTENT.md), not a prerequisite.

## Declaring

Each plugin README carries one line:

```md
Prerequisites: documents, devenv
```

with any subset of `documents`, `baseline`, `structure` in that order, or `Prerequisites: git` for none.
The devkit README table shows the line.
A bundle declares the union of its members' prerequisites, and the validator checks that it does.

Bundle membership follows from the declaration and is never decided by hand: every local plugin outside the marketplace categories `devkit` and `bundle` is in `all`, and every such plugin declaring at most `documents` is in `core`, and no other. The validator checks both.

## The rule

A plugin's text may name a prerequisite it has not declared only inside a conditional section.
The text is every file under the plugin that an agent can read: `SKILL.md`, `references/`, hooks, and the shared documents it symlinks.
The plugin README, `CHANGELOG.md`, `UPSTREAM.md`, licenses and `evals/` are not scanned.

A conditional section is a heading with one of these exact texts, at any level, extending to the next heading of the same or a higher level:

- `With the Lyngon documents`
- `With devenv`: the repository uses devenv at all, a condition rather than a prerequisite
- `With the Lyngon baseline`: which implies devenv
- `With the Lyngon structure`

An agent reads such a section as "only if the repository has this".
The markers to look for: `devenv.nix` exists (devenv); it sets `lyngon.enable = true` (baseline); the root `CLAUDE.md` says "This repository follows the Lyngon structure" (structure).

A skill's `paths` never make it conditional: `*.nix` files exist in repositories that never touch devenv.

Skills that load without being asked, through `paths`, and hooks that run at session start are where unconditional text does the most damage.
They may not say anything above the plugin's declared prerequisites outside a conditional section, and the session hook must check the marker before it mentions the structure.

## The terms

The validator (`scripts/validate-prerequisites.py`) matches these terms, case-sensitively, on every line outside a conditional section:

| Prerequisite | Terms |
| --- | --- |
| `documents` | `CONCEPTS.md`, `docs/adr`, `INTENT.md`, `CLAUDE.md`, `AGENTS.md`, `docs/TODO.md`, `docs/conventions` |
| `devenv` (condition) | `devenv`, `secretspec`, `git-hooks`, `enterTest`, `.pre-commit-config` |
| `baseline` | `lyngon.enable`, `lyngon.structure`, `lyngon.mcp`, `lyngon/devenv`, and the hook names `prose-lint`, `markdownlint`, `nixfmt`, `shellcheck`, `ruff`, `prettier`, `commitizen`, `typos`, `ripsecrets`, `actionlint`, `yamllint`, `deadnix`, `statix`, `golangci-lint` |
| `structure` | `apps/`, `libs/`, `contracts/`, `tools/`, `infra/`, `STRUCTURE.md`, `add-package`, `validate-structure` |

A term of a prerequisite the plugin has not declared, outside the matching conditional section, fails `devenv test`.
The structure implies the baseline (`lyngon.structure.enable` is a baseline option) and the baseline implies devenv, so a section or declaration for the stronger one allows the terms of the weaker ones.
A `SKILL.md` frontmatter (name, description, paths) is metadata and is not scanned.
When a generic sentence trips a term, reword the sentence; do not declare a prerequisite the plugin does not need.
