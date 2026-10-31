# Feature

You own the design, the review and the proof.
Delegates write the code, and you stay the lead.

## What must hold

- The design rests on a traced model of the affected subsystem, from a subagent that invoked `discover:how`.
- The code is built from a named data shape and its organizing structure, per the principle `model-the-domain`: a state machine over scattered booleans, a table or registry over branching, a typed model over repeated assumptions about a shape. You choose it before a delegate writes logic.
- A design that crosses a function boundary was explored through `build:architect` before the code.
- Before any fan-out, the throughput checkpoint is written, one line per dimension. A dimension that does not apply (one file, no fan-out) keeps its line as `n/a: <reason>`.
  - **Blocking first steps.** What must run before any fan-out.
  - **Independent workstreams.** Disjoint files, services or layers run in parallel; shared writes run in sequence.
  - **Shared mutable state.** Split the target by default, per the principle `separate-before-serializing-shared-state`, and serialize only for a real invariant.
  - **Smallest safe decomposition.** When one worker is best, the line says why.
- A `build:implementer` delegate wrote the code, with a specific scope: the file paths, the data shape and its organizing structure, and what must hold when it is done. No reason to skip the delegate counts, the principle `laziness-protocol` included, because the gain is the separation of writing from review, not lines saved. A delegate that may not start subagents meets this by owning the diff directly, with the same separation from your review.
- When the implementation admits several valid shapes (error handling, an abstraction layer, the structure of the tests), the delegates ran through `build:arena`, so that the alternatives surface and a judge guards the pick.
- Edits are surgical. A file derived from an upstream source was compared with that source again. An improvement to a shared primitive reached every consumer, and each consumer was verified.
- A contested design went through `build:review` before the hand-over.

Code that is coupled (one feature, one migration) goes to a single owner with the checkpoint inline, and that owner fans out after the blocking steps.
Fan out at your own level only for slices that produce independent artifacts: audits, investigations across subsystems, competing experiments.
Write the checkpoint again at each phase boundary, and give each phase a fresh owner rather than a chain of resumed ones.

## Proof owed

- The feature verified on the surface where it is used: the CLI run, the page driven, the endpoint called. An inconclusive result, or one from another surface, is not a pass, and the reply says so.
- Commits in the order that proves the work, per the principle `sequence-verifiable-units`: each small unit built, verified and committed before the next.

Then invoke `build:pull-request`.

**Reply:** what you built, what you chose and why, the throughput checkpoint, and the open decisions. Design alternatives go in a table.
