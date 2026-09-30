# Lighter plans

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
Work on the branch `feat/lighter-plans`.

## The problem

`build:plan` writes plans that spell out everything: complete code in every step, every test, every command with its expected output, and every block of prose the implementer copies verbatim.
Its "No placeholders" rule and self-review push toward that for every task, whatever the task's risk.
The owner gates plan (pull request #7, 2026-09-30) ran to 3,430 lines for 13 tasks; writing it took a large share of the session, and reading it was more than a reviewer would do.
Its 13 task reviews found one real issue, while the design-level holes surfaced only in the whole-branch review and the rehearsals.
A complete plan is worth its cost where a cheap implementer transcribes tricky code; elsewhere it spends the planner's time on text an implementer could write from a clear intent.

## What a lighter plan keeps

The design decides the line; these are the owner's starting points:

- Exact values stay exact: interfaces and signatures neighbouring tasks rely on, magic strings, version floors, file paths.
- Tests stay concrete where they pin behaviour, and every mandated check stays proven both ways.
- Prose that carries a decision (an ADR, a working rule, a term) stays dictated, because the implementer would otherwise invent the decision.
- Everything else may be described by intent and acceptance criteria, when the task's implementer tier can write it.

## Decisions to settle

1. What must stay exact in every plan, and what may be written as intent, for code as well as prose.
2. How "No placeholders" and the self-review are reworded so an intent description with acceptance criteria is not a placeholder, while "add error handling" still is.
3. How plan depth ties to the implementer's model tier in `build:delegate`'s Model selection (complete code for the cheapest tier, intent for a mid tier), and to `build:execute`, where the planner is the implementer.
4. Whether the plan gets a size signal (lines per task, or a prompt to split) and what the planner does when a plan grows past it.
5. Whether task review depth scales with it: when `build:plan` recommends `build:execute` with one final review over `build:delegate`'s per-task reviews.
6. What changes in `shared/WORKFLOW.md`, the `build` README and the `plan` skill's `UPSTREAM.md` local patches.

Remove this file and its `docs/TODO.md` entry in the last commit.
