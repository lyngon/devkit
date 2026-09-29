# Changelog

All notable changes to the `discover` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.4.0 - 2026-09-29

- `WORKFLOW.md` names `conventions:engineering` only under a "With the Lyngon workflow" heading, and says the push is left to `/build:finish`.

## 0.3.0 - 2026-09-29

- `approach` runs `review:request` before the pull request and `build:finish` to push the branch and open it. `WORKFLOW.md`, symlinked here, puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request.

## 0.2.1 - 2026-09-29

- `approach` may open the interview with the choice between approaches when that choice decides everything downstream; step 5 then confirms the choice with the trade-offs stated instead of proposing it for the first time.

## 0.2.0 - 2026-09-23

- Added `brainstorm`, an in-house skill for tossing ideas around without writing anything: no rounds, no gate, no `CONCEPTS.md` entries, no ADRs, no plan file.
- `approach` classifies the work as a spike, a bounded change or an architectural change before interviewing, gates implementation on the user's approval, writes the settled design to `docs/plans/YYYY-MM-DD-<slug>.md` and hands it to `build:plan`; the classification, gate and self-review are adapted from obra/superpowers `brainstorming` at commit `5bf4e78`. Agents may now invoke it on their own.
- Added the first eval case, `brainstorm-no-docs`.
- `approach` links the shared `WORKFLOW.md`, which lays out the flow between the discover, build, practice and review skills and the user's gates.

## 0.1.2 - 2026-09-23

- Declares the `documents` prerequisite. The layout examples and the shared format documents no longer assume the Lyngon structure; the core-library placement moved into conditional sections.

## 0.1.1 - 2026-09-20

- `domain-model` layout examples follow the kind-first layout: a context's `CONCEPTS.md` and ADRs live in its core library under `libs/`.

## 0.1.0 - 2026-09-15

- Added `interview`, `domain-model` and `approach`, vendored from mattpocock/skills 1.2.3 at commit `3cca18b` with Lyngon vocabulary (`CONCEPTS.md`, `packages/`).
