---
name: figure-it-out
description: "Design how the work will run before running it, when no narrower skill fits: a large migration, an ambitious multi-part change, or work the owner reviews after stepping away. Frames a falsifiable definition of done, designs a phase list with the verification harness first, runs each unit as an experiment that is kept or reverted, and keeps the decision trail with build:work-trace. Use only when the operator asks for it: 'figure it out', 'figure-it-out'. Not on your own initiative."
argument-hint: "<the task>"
---

# Figure it out

When no narrower skill fits the task, design how the work will run.
The deliverable before any code is the phase list: a sequence of phases that scales rigor to the task, runs the scientific method, and leaves a decision trail the owner can audit after stepping away.

The principles this skill names are files of `principles:index`.
Read each one before you apply it.

The framing and the phase list go into the design file, committed on the branch: the branch's own file under `docs/plans/` when it has one, otherwise a new `docs/plans/YYYY-MM-DD-<slug>.md`.
The build plugin removes the file when the work is finished, as it does every file under `docs/plans/`.

## Frame

Ground first, then commit.
Don't start the run until you can state:

- The definition of done as a falsifiable predicate (the principle `prove-it-works`).
- Scope, quantified: rough units and effort, plus the blockers grounding surfaced.
- The rigor level, biased high. One-way doors and high blast radius get more. Reversible low-stakes steps get less. Rigor is checks and artifacts, not "try harder".

Write the framing and its trade-offs into the design file before a long run starts.
Reversible work proceeds (the principles `never-block-on-the-human` and `review-results-not-plans`).

## Design the phases

Decompose into atomic units that each end in a state you can check.
Sequence riskiest-unknown-first.
Scaffold and verification come before features (the principle `foundational-thinking`).

- Build the verification harness before the work, with the baseline captured from the pre-change state, so the check reads as "old value vs new value".
- For one-way-door design decisions, invoke `build:architect`, which runs `build:arena`, then continue here. Skip it for mechanical work whose shape is already concrete. A second arena over a settled design is over-engineering (the principle `laziness-protocol`).
- Decide what fans out. Parallelize only across seams, and give each worker its own worktree or branch (the principle `separate-before-serializing-shared-state`). Don't over-fan.
- Write the phase list into the design file. That list is what the owner reviews.

When the owner asked for a gate, as in "show me the plan first", stop here.
Commit the design file on the branch, and stop with one question, the last sentence of your reply: whether the owner approves the phase list.
Otherwise go on without stopping.

Then run the phase list.
Run each step under the discipline of "Run the loop", and weave the trail of "Keep the trail" through them, a row as each step lands, rather than saving the whole trail for the end.

## Run the loop

Each unit is an experiment.
State the hypothesis, make the smallest change, measure against the predicate on the real artifact, keep it if it advanced, revert it if it didn't.
Apply the principle `sequence-verifiable-units`, verifying each unit before starting the next instead of batching checks at the end.

- Verify by inspecting the artifact, never a self-report. When something passes too easily, suspect the observation method before the system.
- Pair delegated work with a judge. If a worker games the check, reset and harden the contract. If the check itself is wrong, fix the check in its own change rather than routing around it.
- A verdict is VERIFIED, NOT VERIFIED, or INCONCLUSIVE. Inconclusive is not a pass. Don't hide a negative.

## Keep the trail

Log the run with `build:work-trace`.
`build:pull-request` posts the trail on the pull request, where the reviewer reads it to trust the result.
The trail plus the diff is what lets the owner come back and trust the work.

## Verify and hand back

Check the whole against the predicate from "Frame" on the real product, not just the harness.
Encode any recurring correction as a check, a lint rule, or a script (the principle `encode-lessons-in-structure`).

**Reply:** the phase list you designed, the rigor level and why, the path of the decision trail, what's verified against the predicate, and what's still open.
