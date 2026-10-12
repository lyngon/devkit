# Changelog

All notable changes to the `review` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
The upstream commit of the vendored skills is in their provenance record, `catalog/vendored/superpowers.md` in the devkit.

## 0.4.1 - 2026-10-12

- The provenance of the two skills is one record for their upstream, `catalog/vendored/superpowers.md` in the devkit, where each skill directory held an `UPSTREAM.md` and a `LICENSE`. The upstream license is `LICENSE-superpowers` in the plugin's root, and the README names both.

## 0.4.0 - 2026-10-06

- The whole-branch reviewer checks every task's acceptance lines and states against the branch as it stands, and reports each state as HOLDS or BROKEN in a new output section, "Acceptance lines and states".

## 0.3.1 - 2026-09-29

- The README names the architectural flow next to the bounded one for the review before a pull request, as `request` does.

## 0.3.0 - 2026-09-29

- `request` is mandatory before a pull request is opened rather than before a merge, and Minor findings that nobody fixes go into the pull request description.

## 0.2.0 - 2026-09-29

- The reviewer template takes an optional "State changes since the inputs were written" section (`{STATE_CHANGES}`): the facts that superseded the plan, the spec or an inventory, such as a resource the owner removed by hand, so the reviewer does not report against a world that no longer exists.
- The template says the review package carries every commit's full message, and its git commands include `git log`, so the reviewer can check the commit rules.

## 0.1.0 - 2026-09-23

- Added `request` and `receive`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`requesting-code-review`, `receiving-code-review`) and rewritten to Lyngon vocabulary. The reviewer template takes the plan's review focus and the executor's rulings as optional inputs for the `build` plugin.
