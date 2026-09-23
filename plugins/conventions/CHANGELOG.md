# Changelog

All notable changes to the `conventions` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.1.1 - 2026-09-23

- The `nix` skill no longer assumes devenv or the Lyngon baseline on every Nix file: universal Nix rules first, then `With devenv`, `With the Lyngon baseline` and `With the Lyngon structure` sections. Every "checked by" line moved under `With the Lyngon baseline`, since the hooks come from it.

## 0.1.0 - 2026-09-20

- Added `engineering`, `python`, `typescript`, `nix`, `markdown`, `documents` and `adr`: background skills that load by file path (`paths` frontmatter, `user-invocable: false`) and state the conventions the hooks cannot check.
- Declares the `documents` prerequisite; everything about devenv or the Lyngon structure sits under conditional headings.
- Added the first eval case, `python-domain-value`. `claude plugin eval` is in early access and could not be run here; evals are not wired into CI (token cost).
