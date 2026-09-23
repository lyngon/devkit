---
name: nix
description: Lyngon Nix and devenv conventions. Background knowledge, loaded automatically while working on Nix files and devenv.yaml.
user-invocable: false
paths:
  - "**/*.nix"
  - "devenv.yaml"
---

# Nix and devenv conventions

## devenv

- Every repository sets `lyngon.enable = true` in the root `devenv.nix` and imports `lyngon/devenv` from the `lyngon` input; the baseline hooks, languages and MCP file come from there.
- Override a baseline value in place, with a comment saying why. Never disable a hook to make a check pass.
- Languages are enabled once, in the root `devenv.nix`. A package's `devenv.nix` holds only its tasks, hooks scoped with `files`, and processes.
- Every tool comes from `packages` or a `languages.*` entry; nothing is installed imperatively.
- Inputs are pinned by `devenv.lock`; bump them deliberately with `devenv update <input>` and say why in the commit.
- Do not enable `claude.code.enable`; it overwrites `.claude/settings.json`.
- Secrets come from `secretspec`. No secret value appears in any Nix file.
- `.mcp.json` and `.pre-commit-config.yaml` are generated; never edit them.

## Nix

- Formatted by `nixfmt`; the hook runs it.
- A script that a hook or task runs is a `pkgs.writeShellApplication` with its dependencies in `runtimeInputs`, never a bare path that assumes PATH.
- In a shared module every value is a `lib.mkDefault` so consumers can override. In a repository's own files, plain values.
- No `with pkgs;` at file scope; refer to `pkgs.<name>` so the reader sees where a name comes from.
- No `builtins.fetchurl` or other unpinned fetches; every fetch has a hash.
- Comments say why, not what: what the module does is visible, why a hook is disabled is not.

Checked by: `nixfmt`; `deadnix` and `statix` once the repository enables them.
