# Refactoring

You own the contract.
The structure changes and the behavior does not.

A refactoring is distinct from a feature, which adds behavior, and from a bug fix, which corrects it.
When the cleanup reveals a missing feature or a real bug, split it out, and land the structural change first against the pinned contract.
A redesign is allowed, but name it as one and follow the Feature playbook.
A large or cross-cutting structural change belongs to `build:figure-it-out`, and this playbook covers the focused to medium one.

## What must hold

- The behavior was pinned before any structure moved: a characterization test, a snapshot or an equivalence harness that captures the current behavior, written from the contract that a subagent's `discover:how` traced. Type checking and linting are not a pin. An area without coverage gets its pin first.
- The structure the code is missing is named, per the principle `model-the-domain`. Plain code stays where its shape is already clear and local. The reshape deletes branches or invalid states and adds no indirection.
- The target shape is named: the module layout, the types and the call graph as they would be if built today, per the principles `foundational-thinking` and `redesign-from-first-principles`. A target that crosses a function boundary was explored through `build:architect` before the move.
- Dead code, one-caller wrappers, redundant validators and orphan references were deleted before the new shape went in, per the principle `subtract-before-you-add`. The smallest change that reaches the target ships, per the principle `laziness-protocol`, and a speculative cleanup that "might help" is reverted.
- Each step kept the pin green. An interface that changed shape had every caller migrated and the old interface deleted in the same wave, per the principle `migrate-callers-then-delete-legacy-apis`, with no compatibility shim and no parallel old and new paths.
- Every rename was checked against the files. A rename misses uses in strings, in prose and in back-references without any error.
- Mechanical edits went to a `build:implementer` delegate, with the file paths, the names being moved and the behavior to hold.

## Proof owed

- Behavior unchanged on the real artifact, not "it compiles", per the principle `prove-it-works`. A larger reshape gets an equivalence check: a script that diffs old and new outputs, a recorded baseline replayed against the new code, or a run on the surface where the code is used.
- Lower reader load somewhere, per the principle `minimize-reader-load`. A diff that lowers it nowhere is reverted.
- Commits that tell the story: the subtraction, then the reshape, then any cleanup that follows, each slice green before the next, per the principle `sequence-verifiable-units`.

Then invoke `build:pull-request`.

**Reply:** the structure that changed, the pin it was held against, the proof of equivalence, the change in reader load, and what shipped and what was reverted. No new behavior.
