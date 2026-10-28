# conventions

Organization-wide conventions that reach every agent in every Lyngon repository without a copy in any of them.

Each skill carries `paths` and `user-invocable: false` in its frontmatter, and a description that ends with when to invoke it.
A skill's body reaches the agent only when the agent invokes it; `paths` does not load it.
The plugin's `SessionStart` hook says so at the start of every session.
The bodies are short on purpose, because agents invoke them in almost every session.
Every rule a linter can check lives in the linter, not here; each skill ends with the hooks that check its deterministic half.
The `decision-record` and `documents` skills carry format documents adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT); the license is `LICENSE-mattpocock` in this plugin.

## Skills

| Skill | Invoke before working on |
| --- | --- |
| `engineering` | every file |
| `python` | `*.py`, `*.pyi`, `*.ipynb` |
| `typescript` | `*.ts`, `*.tsx`, `*.mts`, `*.cts`, `*.js`, `*.jsx`, `*.mjs`, `*.cjs` |
| `nix` | `*.nix`, `devenv.yaml` |
| `shell` | `*.sh`, `*.bash`, files under a `scripts/` directory |
| `markdown` | `*.md` |
| `documents` | `INTENT.md`, `CONCEPTS.md`, `README.md`, `.claude/CLAUDE.md`, `.claude/rules/*.md` |
| `decision-record` | `docs/decisions/*.md` |

## Hooks

- `SessionStart`: prints `hooks/session-start.txt`, which says to invoke the conventions skill for a file's kind before editing that file, and that none loads on its own. The standing instructions come from the hook of the `build` plugin.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```
