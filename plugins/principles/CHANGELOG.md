# Changelog

All notable changes to the `principles` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
The upstream commit of the vendored principles is in their provenance record, `catalog/vendored/pstack.md` in the devkit.

## 0.2.1 - 2026-10-12

- The provenance of the 24 vendored principles is in the record of their upstream, `catalog/vendored/pstack.md` in the devkit, where the skill directory held an `UPSTREAM.md` and a `LICENSE`. The upstream license is `LICENSE-pstack` in the plugin's root, and the README names both.

## 0.2.0 - 2026-10-11

- `record-what-the-code-cannot-show` covers steering documents and code comments, where it covered all prose in the tree. A README, a changelog, a provenance record and user documentation are outside it, and it says when a comment passes the admission test.

## 0.1.1 - 2026-10-11

- The index no longer names the provenance record, which an agent reading the index has no use for.

## 0.1.0 - 2026-10-11

- Added `index` with 32 principles, one line each in `SKILL.md` and one file each under `references/`.
- 24 are vendored from pstack 0.15.15 at commit `9f451cf`: `never-block-on-the-human` states the Lyngon gate, `encode-lessons-in-structure` routes a lesson to the pull request, a check or a principle, `outcome-oriented-execution` keeps breakage inside a branch, and `sequence-verifiable-units` makes the change the unit that lands.
- 8 are written by Lyngon: `record-what-the-code-cannot-show`, `the-tree-is-current`, `review-results-not-plans`, `fix-debt-in-its-own-change`, `reshape-instead-of-commenting`, `name-things`, `prescribe-proof-not-steps` and `use-purpose-built-tools`.
