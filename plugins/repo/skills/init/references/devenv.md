# devenv

Assumes devenv 2.3 or later.
The root `devenv.nix` holds the languages, cross-cutting tools and hooks; each package holds its own `devenv.nix` with its tasks, hooks and processes; the root `devenv.yaml` imports the packages.

## Root files

### devenv.yaml

```yaml
# yaml-language-server: $schema=https://devenv.sh/devenv.schema.json
require_version: ">=2.3.0"

inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  lyngon:
    url: github:lyngon/devkit
    flake: false

imports:
  - lyngon/devenv
  - ./apps/{name}
  - ./libs/{name}
```

The `lyngon` input is the shared baseline module from the Lyngon devkit; `devenv update lyngon` bumps it.
The `git-hooks` input must be declared here because a remote import cannot add inputs.

Add `nixpkgs.allow_unfree: true` only when a package needs an unfree tool, and say which in a comment.
Add the `secretspec` section when the repository needs secrets (see below).

### devenv.nix

```nix
{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Baseline git hooks, the devenv MCP server file, and the Nix and shell
  # languages come from the lyngon input. Override a baseline hook only with
  # a comment saying why, e.g. `git-hooks.hooks.typos.enable = false;`.
  lyngon.enable = true;
  # The repository follows the Lyngon structure; enables the validate-structure hook.
  lyngon.structure.enable = true; # {structure scope only}

  # Languages are enabled once, here, for the workspace at the root.
  languages.python = {
    enable = true;
    uv.enable = true;
    uv.sync.enable = true;
  };

  packages = [ pkgs.jq ];

  # `devenv test` runs every git hook on every file first, then this.
  enterTest = ''
    {repository-wide test command, or nothing}
  '';
}
```

The baseline is: nixfmt, shellcheck, markdownlint (one sentence per line, no length limit), ripsecrets, typos, end-of-file-fixer, trim-trailing-whitespace, check-merge-conflicts, commitizen, actionlint, yamllint (relaxed), and validate-structure (the dependency rules, member lists and package file set from `STRUCTURE.md`).

Do not enable `claude.code.enable`.
It would take over `.claude/settings.json` with a fixed key set and drop the marketplace registration.
Do not enable Claude Code hooks through devenv; the git hooks are the feedback loop, and the one Claude Code hook a Lyngon repository has comes from the `repo` plugin.

### .envrc

```bash
#!/usr/bin/env bash

eval "$(devenv direnvrc)"

use devenv
```

`.envrc` serves direnv users and the `mkhl.direnv` VS Code extension.
Users without direnv get activation from `devenv hook <shell>` in their own shell configuration plus `devenv allow` in the repository; the repository cannot configure that for them, so the README says how.

## Package files

A package's `devenv.nix` (`apps/{name}/devenv.nix`, `libs/{name}/devenv.nix`) holds its tasks, package-scoped hooks and processes.
It never enables a language; the workspace at the root owns the language, the lockfile and the environment.
Hooks are repository-wide in devenv, so scope them with `files`:

```nix
{ ... }:
{
  git-hooks.hooks = {
    ruff-format = {
      enable = true;
      files = "^libs/{name}/";
    };
    ruff = {
      enable = true;
      files = "^libs/{name}/";
    };
  };

  tasks."{name}:test" = {
    description = "Run {name} tests";
    exec = "cd libs/{name} && uv run pytest";
  };
}
```

The `add-package` skill writes this file; its `workspaces.md` reference has the root workspace file per language.

Wire package tests into the root `enterTest` by task name, or list the commands in `CLAUDE.md` when they are slow.

## Stacks

`languages.*` goes in the root `devenv.nix`, once per language.
Formatters are always enabled.
Linters are enabled when they need no project configuration.
Linters that need configuration (eslint, clippy) are written as commented-out lines with a one-line reason, for the owner to enable.
Hook names are exact `git-hooks.hooks.<name>` names from git-hooks.nix.

| Stack | `languages.*` | Formatter hooks | Linter hooks | Commented out | `.gitignore` |
| --- | --- | --- | --- | --- | --- |
| Python (uv) | `python = { enable = true; uv.enable = true; uv.sync.enable = true; }` | `ruff-format` | `ruff` | | `__pycache__/`, `*.py[cod]`, `.venv/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `dist/`, `*.egg-info/` |
| TypeScript (pnpm) | `javascript = { enable = true; pnpm.enable = true; pnpm.install.enable = true; }; typescript.enable = true;` | `prettier` | | `eslint` (needs `eslint.config.js`) | `node_modules/`, `dist/`, `.pnpm-store/`, `*.tsbuildinfo`, `coverage/` |
| Rust | `rust.enable = true;` (channel `nixpkgs`; use `channel = "stable"` with the `rust-overlay` input only when a newer toolchain is required) | `rustfmt` | | `clippy` (compiles the crate on every commit) | `target/` |
| Go | `go.enable = true;` | `gofmt` | `golangci-lint` | | `/bin/`, `*.test`, `coverage.out` |
| Nix | `nix.enable = true;` | `nixfmt` (baseline) | `deadnix`, `statix` | | |
| Shell | `shell.enable = true;` | `shfmt` | `shellcheck` (baseline) | | |
| Terraform | `terraform.enable = true;` | `terraform-format` | `tflint` | | `.terraform/`, `*.tfstate`, `*.tfstate.*`, `crash.log`, `*.tfvars` (may hold secrets; `.terraform.lock.hcl` is committed) |
| Haskell | `haskell.enable = true;` (`stack.enable` and `cabal.enable` default to true; disable the one not used) | `ormolu`, `cabal-fmt` | `hlint` | | `dist-newstyle/`, `.stack-work/`, `*.hi`, `*.o` |

A stack outside this table gets `languages.<name>.enable = true` when devenv has it, no hooks beyond the baseline, and a note in `CLAUDE.md` that hooks for it are not configured.

## Secrets

Always `secretspec`.
When the interview names secrets:

`devenv.yaml`:

```yaml
secretspec:
  enable: true
  profile: development
  provider: keyring
```

`secretspec.toml`:

```toml
[project]
name = "{repository name}"
revision = "1.0"

[profiles.default]
{SECRET_NAME} = { description = "{what it is for}", required = true }

[profiles.development]
{SECRET_NAME} = { description = "{what it is for}", required = false }
```

Providers: `keyring` for developers, `env` for CI, `dotenv` only when the user asks; `onepassword` and `lastpass` exist too.
Never write a secret value anywhere in the repository.
Mention in `CLAUDE.md` that secrets come from `secretspec` and are never inlined.

## Services

Only for services the user confirmed by name in the interview:

```nix
services.postgres = {
  enable = true;
  initialDatabases = [ { name = "{name}"; } ];
};
```

Never add a service because the stack suggests one.

## Activation and editors

- **direnv**: `direnv allow` once; `.envrc` does the rest.
- **devenv hook**: `eval "$(devenv hook zsh)"` (or `bash`, `fish`; `devenv hook fish | source`) in the user's shell configuration, then `devenv allow` in the repository. Subshell-based, deactivates on leaving the directory.
- **VS Code**: the `mkhl.direnv` extension loads `.envrc` into the extension host, so the Claude Code extension and integrated terminals see the devenv tools. Without it, Claude Code hooks and MCP servers still load (they are files), but the tools they call are missing from PATH.
- **AI agents**: devenv detects Claude Code and switches to quiet, non-TUI output on its own. Set `DEVENV_NO_AI_AGENT=1` to disable that.

## Verification

```sh
devenv test
```

runs `prek run --all-files` for every hook and then `enterTest`.
When a hook fails on generated or vendored files, exclude the path with `excludes` on that hook rather than disabling the hook.
