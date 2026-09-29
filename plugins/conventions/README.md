# conventions

Organization-wide conventions that reach every agent in every Lyngon repository without a copy in any of them.

Prerequisites: documents

Each skill carries `paths` and `user-invocable: false` in its frontmatter, and a description that ends with when to invoke it.
A skill's body reaches the agent only when the agent invokes it; `paths` does not load it.
The plugin's `SessionStart` hook says so at the start of every session, together with which devkit skills to invoke and when.
The bodies are short on purpose, because agents invoke them in almost every session.
Every rule a linter can check lives in the linter, not here; each skill ends with the hooks that check its deterministic half.
The `adr` and `documents` skills carry format documents adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT); the license is `LICENSE-mattpocock` in this plugin.

## Skills

| Skill | Invoke before working on |
| --- | --- |
| `engineering` | every file |
| `python` | `*.py`, `*.pyi`, `*.ipynb` |
| `typescript` | `*.ts`, `*.tsx`, `*.mts`, `*.cts`, `*.js`, `*.jsx`, `*.mjs`, `*.cjs` |
| `nix` | `*.nix`, `devenv.yaml` |
| `shell` | `*.sh`, `*.bash`, files under a `scripts/` directory |
| `markdown` | `*.md` |
| `documents` | `CLAUDE.md`, `AGENTS.md`, `CONCEPTS.md`, `INTENT.md`, `README.md` |
| `adr` | `docs/adr/*.md` |

## Hooks

- `SessionStart`: prints `hooks/session-start.txt`, which says which devkit skills to invoke and when, and that no skill loads on its own, the conventions included.

## Install

Part of the `all` bundle.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install conventions@lyngon --scope project
```
