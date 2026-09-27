# Roadmap for multi-piece work

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request, and let it classify the work.
If it turns out bounded, finish it in the same session.

## The problem

Step 3 of the architectural path in `discover:approach` decomposes a request that spans several subsystems into pieces, each with its own design, plan and implementation cycle.
Nothing holds the order of the pieces and the facts they share.
In lyngon.com (2026-09-27) the first session needed a hand-made overview file and a "Facts the next pieces need" record kept in a commit message, and the next session could not find that record because it existed only on `origin/main`.
`build:finish` removes plan files when a piece lands, so a plan cannot carry the roadmap.

## Constraints

- ADR 0016: plans are transient, live on the branch and are removed when the work lands; a fact that outlives the work belongs in `CONCEPTS.md`, an ADR or `CLAUDE.md`, never in a plan.
- `docs/TODO.md` holds only work the owner explicitly deferred.
- A roadmap is work in progress for as long as any piece is unbuilt, so keeping it until the last piece lands is consistent with the ADR.

## Decisions to settle

1. Name and location, for example `docs/plans/YYYY-MM-DD-<slug>-roadmap.md`, and whether it lives on `main` or on each piece's branch.
2. Content: the pieces, their order, the status of each, the transient facts the later pieces need, and a pointer to each piece's plan; nothing that belongs in the Lyngon documents.
3. Who writes and updates it: `discover:approach` at decomposition, `build:finish` when a piece lands (status) and when the last piece lands (removal).
4. How a fresh session finds it: the session-start hook, a link from each piece's plan, or a convention in the plan header.
5. Its relation to the pause record of `docs/seed-prompts/owner-gates.md`, so the two do not become two files for one purpose.
