# Changelog

All notable changes to the `discover` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.10.1 - 2026-10-11

- `CONCEPTS-FORMAT.md` and `DECISION-RECORD-FORMAT.md`, symlinked into `domain-model`, no longer name the license file and the provenance record of the format they were adapted from. The README does.

## 0.10.0 - 2026-10-11

- Added `why`, vendored from pstack 0.15.15 at commit `9f451cf`: it answers why code, a design or a decision is the way it is from the decision records (the deleted ones included), git, pull request bodies and issues, and marks every claim as found, inferred or unknown. With git and GitHub as the only sources it runs in one pass; with another source behind an MCP it spawns one investigator per source and a synthesizer. The playbook for GitHub Issues is adapted from upstream's playbook for Linear, and upstream's playbooks for Slack, Notion, Datadog, Sentry and Databricks are left out.

## 0.9.0 - 2026-10-11

- `domain-model` records decisions as decision records: in `docs/decisions/`, named after the decision without a number, and offered by the admission test, which replaces the three criteria. Its format document is now `DECISION-RECORD-FORMAT.md`, and a repository's override moves to `docs/conventions/decision-record.md`.
- `approach` and `brainstorm` say decision records and `docs/decisions/` where they said ADRs and `docs/adr/`.
- `WORKFLOW.md`, symlinked into `approach`, says the same.

## 0.8.0 - 2026-10-06

- `WORKFLOW.md`, symlinked into `approach`, says what a plan holds (interfaces, acceptance lines, dictated text, owner gates and mandated checks, with the implementer writing the tests and the code), that the task reviewer gives a verdict on every acceptance line, and which plans suit `/build:execute`.

## 0.7.0 - 2026-10-06

- `approach` checks in the self-review of its design file that every value an implementer must use exactly is stated and every edge behaviour is named with its outcome, since a plan copies them from the design and decides none.

## 0.6.1 - 2026-09-30

- `WORKFLOW.md`, symlinked into `approach`, names the executor's "Owner gates" list beside "Rulings I made" and "Deferred minors" at the second review gate.

## 0.6.0 - 2026-09-30

- `WORKFLOW.md`, symlinked into `approach`, names the review gates and the owner gates, pre-approval by ID, the protocol every stop runs, the Execution status and the record commits.

## 0.5.0 - 2026-09-30

- `ADR-FORMAT.md`, symlinked into `domain-model`, says when an accepted ADR may be edited and that every edit adds a line to its `## Change log`.

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
