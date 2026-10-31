---
name: approach
description: "The owner's gate on a design: interview the owner on what only they can settle, write CONCEPTS.md terms and decision records as they settle, write the design file under docs/plans/, and stop until the owner approves it. Only the operator starts it, as /discover:approach with the request."
argument-hint: "[--no-docs] <the request to design>"
disable-model-invocation: true
---

# Approach

The operator started this skill to settle a design with the owner before anything is built.
It ends at the owner's approval of the design file.

## What must hold

- The interview ran through `discover:interview`, in rounds until the frontier was empty, on what only the owner can settle: the goal, the scope, a product or preference call, a trade-off that no run can decide. What the repository or a run can answer was looked up and not asked.
- Each term and each decision that settled during the interview was written as it settled, through `discover:domain-model`, into `CONCEPTS.md` and `docs/decisions/`. With `--no-docs`, only `discover:interview` ran, and neither was written.
- The design is in `docs/plans/YYYY-MM-DD-<slug>.md`, or in the branch's own file under `docs/plans/` when it has one, committed on a branch named `<type>/<slug>`.
- The file holds the goal and what done means, the alternatives compared and why the chosen one won, the components, and the proof owed: what a reviewer can rerun or read to see that the work holds. Each part is as long as its complexity needs.
- What must outlive the work is in a steering document, not only in the file. The file is transient, and the change that finishes the work removes it.
- Nothing else in the repository changed: no code, no scaffolding, no dependency.
- The reply ends with one question, its last sentence: whether the owner approves the design.

When the owner asks for changes, make them in the file, commit, and ask again.
The owner's approval ends this skill.
The work then goes on under the standing instructions, and under `/build:auto` only when the operator starts it.

To toss ideas around without any of this, use `discover:brainstorm`.
