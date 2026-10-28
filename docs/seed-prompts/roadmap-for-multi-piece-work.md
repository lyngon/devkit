# Roadmap for multi-piece work

Seed prompt for a fresh Claude Code session in the devkit repository.

Start the session with `/discover:approach`, with this file as its argument: only the operator can start that skill.

## The problem

A request that spans several subsystems is split into pieces, each with its own design and pull request.
Nothing holds the order of the pieces and the facts they share.
In lyngon.com (2026-09-27) the first session needed a hand-made overview file and a "Facts the next pieces need" record kept in a commit message, and the next session could not find that record because it existed only on `origin/main`.
The change that finishes a piece removes its design file under `docs/plans/`, so a design file cannot carry the roadmap.

## Constraints

- The rule file `work-in-progress-files.md`: a design file under `docs/plans/` is transient, lives on its branch and is removed by the change that finishes the work; a fact that outlives the work belongs in a steering document, never in a design file.
- `docs/TODO.md` holds only work the owner explicitly deferred.
- A roadmap is work in progress for as long as any piece is unbuilt, so keeping it until the last piece lands is consistent with that rule.

## Decisions to settle

1. Name and location, for example `docs/plans/YYYY-MM-DD-<slug>-roadmap.md`, and whether it lives on `main` or on each piece's branch.
2. Content: the pieces, their order, the status of each, the transient facts the later pieces need, and a pointer to each piece's design file; nothing that belongs in the Lyngon documents.
3. Who writes and updates it: `/discover:approach` at decomposition, `build:pull-request` when a piece lands (status) and when the last piece lands (removal).
4. How a fresh session finds it: the session-start hook, a link from each piece's design file, or a convention in the design file's header.
