# conventions

Organization-wide conventions that reach every agent in every Lyngon repository without a copy in any of them.

Prerequisites: documents

Each skill carries `paths` in its frontmatter and `user-invocable: false`: it loads on its own when the agent works on a matching file and is never invoked by name.
The bodies are short on purpose, because they ride along with every matching edit.
Every rule a linter can check lives in the linter, not here; each skill ends with the hooks that check its deterministic half.
The `adr` and `documents` skills carry format documents adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT); the license is `LICENSE-mattpocock` in this plugin.

## Skills

| Skill | Loads for |
| --- | --- |
| `engineering` | every file |
| `python` | `*.py`, `*.pyi`, `*.ipynb` |
| `typescript` | `*.ts`, `*.tsx`, `*.mts`, `*.cts`, `*.js`, `*.jsx`, `*.mjs`, `*.cjs` |
| `nix` | `*.nix`, `devenv.yaml` |
| `markdown` | `*.md` |
| `documents` | `CLAUDE.md`, `AGENTS.md`, `CONCEPTS.md`, `INTENT.md`, `README.md` |
| `adr` | `docs/adr/*.md` |

## Install

Part of the `all` bundle.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install conventions@lyngon
```
