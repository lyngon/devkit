# Session wrap-up skill

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
It is a new skill, so the design decides its plugin, its name and its place in `shared/WORKFLOW.md`.

## The problem

A session that ends well leaves the documents current, the branch clean, a way to continue, and its lessons where they will be acted on.
No skill does this, so the owner asks for it by hand at the end of every session, and the results vary.
The idea was deferred on 2026-09-26 (working name `conclude`); on 2026-09-27 a lyngon.com session ran the whole procedure by hand, which settled what it needs.

## What it does

- Makes sure the documents are up to date and the repository and branch are in a clean state.
- Suggests the prompts for continuing the work in a new session, and writes a handover document when a lot of context is needed.
- Suggests process improvements: misleading or suboptimal devkit skills, missing conventions, friction in the flow.
  Its devkit suggestions come out as one paste-ready prompt for a fresh session in the devkit, like the files in `docs/seed-prompts/`, and they extend existing entries of the devkit's `docs/TODO.md` instead of repeating them, so the skill reads that file first.
- Gives feedback on the session itself: what was enjoyable, what was not, in the agent's own words.

## Constraints from the hand run

- It runs after the owner picks from the integration menu of `build:finish` and before the push, so the `docs/TODO.md` and document commits land in the same pull request.
  A session without `build:finish` runs it at the end.
- It must read the devkit's `docs/TODO.md`, which is not part of any plugin; the design decides how a session in a consuming repository reads it (a local checkout at a known path, the file on GitHub, or a copy the plugin ships).

## Decisions to settle

1. Plugin and name: a skill in `build` next to `finish`, in `review`, or a new plugin; prerequisites (`documents` only, most likely).
2. Trigger: user-invoked (`/conclude`), invoked by `build:finish` before the push, or both.
3. The output format of the devkit-feedback prompt: verified claims with paths and line numbers, one prompt per suggestion or one prompt for the session, and how it references existing `docs/TODO.md` entries.
4. Where the handover document lives (`docs/plans/`, `tmp/`, or the roadmap of `docs/seed-prompts/roadmap-for-multi-piece-work.md`) and when it is removed.
5. Whether the related deferred items belong here: ending every turn with suggested next actions, and estimating context use to propose checkpoints.
