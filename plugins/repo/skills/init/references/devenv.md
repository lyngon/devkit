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
Linters whose configuration `init` writes (ruff, eslint) are enabled with it.
Linters that need configuration `init` does not write (clippy) are written as commented-out lines with a one-line reason, for the owner to enable.
Hook names are exact `git-hooks.hooks.<name>` names from git-hooks.nix.

| Stack | `languages.*` | Formatter hooks | Linter hooks | Commented out | `.gitignore` |
| --- | --- | --- | --- | --- | --- |
| Python (uv) | `python = { enable = true; uv.enable = true; uv.sync.enable = true; }` | `ruff-format` | `ruff` | | `__pycache__/`, `*.py[cod]`, `.venv/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `dist/`, `*.egg-info/` |
| TypeScript (pnpm) | `javascript = { enable = true; pnpm.enable = true; pnpm.install.enable = true; }; typescript.enable = true;` | `prettier` | `{name}-tsc`, `{name}-eslint` (custom, below) | | `node_modules/`, `dist/`, `.pnpm-store/`, `*.tsbuildinfo`, `coverage/` |
| Rust | `rust.enable = true;` (channel `nixpkgs`; use `channel = "stable"` with the `rust-overlay` input only when a newer toolchain is required) | `rustfmt` | | `clippy` (compiles the crate on every commit) | `target/` |
| Go | `go.enable = true;` | `gofmt` | `golangci-lint` | | `/bin/`, `*.test`, `coverage.out` |
| Nix | `nix.enable = true;` | `nixfmt` (baseline) | `deadnix`, `statix` | | |
| Shell | `shell.enable = true;` | `shfmt` | `shellcheck` (baseline) | | |
| Terraform | `terraform.enable = true;` | `terraform-format` | `tflint` | | `.terraform/`, `*.tfstate`, `*.tfstate.*`, `crash.log`, `*.tfvars` (may hold secrets; `.terraform.lock.hcl` is committed) |
| Haskell | `haskell.enable = true;` (`stack.enable` and `cabal.enable` default to true; disable the one not used) | `ormolu`, `cabal-fmt` | `hlint` | | `dist-newstyle/`, `.stack-work/`, `*.hi`, `*.o` |

A stack outside this table gets `languages.<name>.enable = true` when devenv has it, no hooks beyond the baseline, and a note in `CLAUDE.md` that hooks for it are not configured.

### Python: ruff.toml

Written at the repository root when Python is in the stack.
It selects every stable rule; each ignore carries its reason.
`target-version` comes from `requires-python` in the root `pyproject.toml`.

```toml
[lint]
select = ["ALL"]
ignore = [
  "COM812",  # conflicts with the formatter
  "D105",    # magic methods document themselves
  "D107",    # the class docstring covers __init__
  "D203",    # D211 is kept: no blank line before a class docstring
  "D213",    # D212 is kept: the summary starts on the first line
  "EM101",   # a plain message literal in raise is readable
  "FIX002",  # TODOs are allowed; TD checks their form
  "SIM108",  # a ternary is not always clearer than if/else
  "TC001",   # annotation imports stay at runtime: pydantic and FastAPI evaluate them
  "TC002",
  "TC003",
  "TD002",   # no author on a TODO; git blame has it
  "TD003",   # no issue link required on a TODO
]

[lint.per-file-ignores]
"**/tests/**" = [
  "D1",      # test names state the behaviour
  "INP001",  # pytest collects tests/ without __init__.py
  "PLR2004", # expected values are literals
  "S101",    # pytest asserts
]

[lint.flake8-import-conventions]
banned-from = ["collections.abc", "datetime", "typing"]

[lint.flake8-import-conventions.extend-aliases]
"collections.abc" = "ct"
"datetime" = "dt"
"typing" = "t"

[lint.flake8-tidy-imports]
ban-relative-imports = "all"
```

It is the only ruff configuration in the repository.
Ruff uses the nearest configuration and does not merge, so a `[tool.ruff]` table in a package's `pyproject.toml` would silently replace this file for that package.
In adopt mode, move an existing ruff configuration here and show the diff; carry over an ignore only with its reason.
Existing code that fails the new rules is fixed, or the owner accepts a temporary ignore with a reason; never lower the selection to make code pass.

### TypeScript: tsconfig.base.json and eslint.config.js

Written at the repository root when TypeScript is in the stack.
The compiler and the linter are separate checks: `tsc` enforces the flags, typescript-eslint adds the rules that need type information and that `tsc` does not check (floating promises, `any` leaking through untyped values, exhaustive `switch`).

The lint and compiler dependencies go in the root `package.json`, which is private and holds no code:

```json
{
  "name": "{repository}",
  "private": true,
  "type": "module",
  "devDependencies": {
    "@eslint/js": "^10.0.1",
    "eslint": "^10.11.0",
    "eslint-plugin-import-x": "^4.17.1",
    "typescript": "~6.0.3",
    "typescript-eslint": "^8.70.1"
  }
}
```

Add them with `pnpm add -w -D`, then set `typescript` to `~6.0.3` by hand if pnpm chose a newer major.
typescript-eslint 8 supports TypeScript below 6.1; TypeScript 7 (the native compiler) has no JavaScript API for it yet.
Lift the pin when typescript-eslint's `typescript` peer range includes 7.

`unrs-resolver`, a dependency of `eslint-plugin-import-x`, has an install script that only builds a fallback for platforms without a prebuilt binary.
pnpm 11 refuses unreviewed install scripts, so deny it in `pnpm-workspace.yaml`:

```yaml
allowBuilds:
  unrs-resolver: false
```

`tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "es2024",
    "lib": ["es2024"],
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "allowUnreachableCode": false,
    "allowUnusedLabels": false,
    "verbatimModuleSyntax": true,
    "erasableSyntaxOnly": true,
    "isolatedModules": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  }
}
```

`lib` holds only the language; a package adds `"dom"` or `"types": ["node"]` (with `@types/node` as its dev dependency) for its runtime.

`eslint.config.js`:

```js
import js from "@eslint/js";
import { importX } from "eslint-plugin-import-x";
import { defineConfig } from "eslint/config";
import * as module from "node:module";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["**/dist/", "**/generated/"] },
  js.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { "import-x": importX },
    rules: {
      // Not in the presets.
      "@typescript-eslint/strict-boolean-expressions": [
        "error",
        { allowNumber: false, allowString: false },
      ],
      "@typescript-eslint/switch-exhaustiveness-check": [
        "error",
        {
          considerDefaultExhaustiveForUnions: true,
          requireDefaultForNonUnion: true,
        },
      ],
      // Named exports only.
      "import-x/no-default-export": "error",
      // Node builtins: the node: prefix, imported as a namespace.
      "no-restricted-imports": [
        "error",
        {
          paths: module.builtinModules
            .filter((name) => !name.startsWith("node:"))
            .map((name) => ({ name, message: `Import "node:${name}".` })),
        },
      ],
      "no-restricted-syntax": [
        "error",
        {
          selector:
            "ImportDeclaration[source.value=/^node:/] > :matches(ImportSpecifier, ImportDefaultSpecifier)",
          message:
            'Import a Node builtin as a namespace: import * as fs from "node:fs".',
        },
      ],
    },
  },
  {
    // Configuration files are plain JavaScript outside every tsconfig.
    files: ["**/*.js", "**/*.mjs", "**/*.cjs"],
    extends: [tseslint.configs.disableTypeChecked],
  },
  {
    // Tools read their configuration through the default export.
    files: ["**/*.config.{js,mjs,cjs,ts,mts,cts}"],
    rules: { "import-x/no-default-export": "off" },
  },
);
```

It is plain JavaScript because ESLint reads it directly, and it is the only ESLint configuration in the repository.

A package's `tsconfig.json` extends the base and sets only what its runtime needs:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "noEmit": true, "types": ["node"] },
  "include": ["src", "tests"]
}
```

The package's `devenv.nix` runs both checks.
They are custom hooks because the `eslint` hook in git-hooks.nix runs the nixpkgs ESLint, which cannot load the workspace's typescript-eslint:

```nix
git-hooks.hooks = {
  "{name}-tsc" = {
    enable = true;
    name = "{name} tsc";
    entry = "pnpm exec tsc -p libs/{name}";
    files = "^libs/{name}/.*\\.(ts|tsx|mts|cts)$";
    pass_filenames = false;
  };
  "{name}-eslint" = {
    enable = true;
    name = "{name} eslint";
    entry = "pnpm exec eslint --max-warnings 0 --no-warn-ignored";
    files = "^libs/{name}/.*\\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$";
  };
};
```

In adopt mode, move an existing ESLint configuration and compiler flags into these files and show the diff.
Existing code that fails is fixed, or the owner accepts a scoped `rules` override with a reason; never drop a preset to make code pass.

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
