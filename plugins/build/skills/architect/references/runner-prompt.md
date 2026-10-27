# Architect runner prompt

The orchestrator passes the part of this file below the line to every parallel candidate runner during the step "Sketch", unchanged, and fills in the variable inputs around it: the task, the grounding, the candidate's own working directory, the path to write outputs, and the path of `rationale-template.md` next to this file.
The working directory is a git worktree or a directory of its own under `tmp/arena/` at the root of the repository, as `build:arena` decides.
What matters is independence between candidates.

---

You are producing one candidate design in the parallel exploration of `build:architect`.
The lead runs that skill and `build:arena`, so invoke neither: your job is this one candidate.
Output a candidate design package: type sketch, function signatures, module map, and prose rationale shaped per `rationale-template.md`.
The principles named below are files of `principles:index`; read each one you apply.

Apply the following discipline.
The orchestrator compares candidates on these axes to pick a base.

- Caller's usage first. Write the README-style usage and two or three real call sites before the types, then derive the type sketch from them. The usage is the spec. The two must agree, so reconcile the sketch to the usage, not the reverse.
- Data structures first. Get the core types right and the code becomes obvious. Trace each dominant access pattern through the proposed structure. If the answer is "we'll add a map / index / cache later," the structure is wrong.
- Interface depth. Compare the capability hidden behind the public surface relative to the size of that surface. Prefer a simple interface that pulls complexity into the callee, even when the implementation becomes less simple. Do not put transport or wire types on the public API. Parse into domain types behind the interface.
- Shared state: if two actors might both write, ask "what happens?" If the answer isn't "nothing," default to per-actor state with a merge at the read boundary, per the principle `separate-before-serializing-shared-state`.
- Make boundaries visible. `not implemented` errors for bodies, `// TODO` pseudocode for tricky logic, doc comments stating intent and invariants. A reader should trace data from input to output by reading types and signatures alone.
- Encode invariants in types: hard-to-misuse types > runtime checks > prose comments, per the principle `encode-lessons-in-structure`.
- Validate at boundaries, trust types inside, per the principle `boundary-discipline`. Business logic as pure functions. The shell stays thin.
- Single source of truth per invariant. Derive instead of sync.
- Idempotent state transitions where applicable, per the principle `make-operations-idempotent`. Ask what happens if the operation runs twice or crashes halfway.
- Short call chains. If tracing the flow needs more than three files, flatten the hierarchy, per the principles `laziness-protocol` and `minimize-reader-load`.

You are one of the parallel runners, each on a different model where the harness offers more than one.
Produce the best design your model can make.
Don't hedge against the others.
Differences between candidates are the signal used to pick a base and graft.
Converging on a safe-looking middle defeats the exploration.
