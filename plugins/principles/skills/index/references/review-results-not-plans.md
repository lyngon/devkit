# Review results, not plans

The owner steers through steering documents and reviews results.
Nothing waits for approval by default.
A gate on requirements, a specification, a plan or tasks exists if and only if the owner asked for it explicitly, and then the agent stops there.

**Why:** Approval before the work spends the owner's attention on a prediction, and the result still has to be reviewed.
A steering document carries the owner's direction into every session, where an approval carries it into one.
Process is better spent on proof than on permission.
A result with evidence can be judged, and a plan can only be believed.

**Pattern:**

- Take direction from the steering documents and the task. Where they are silent, decide, act, and list the decision in the pull request.
- Hand over a result with its proof: what was done, what was run, what it showed.
- When the owner asks for a gate ("show me the plan first"), stop at exactly that gate and wait.
- Never invent a gate. "Should I proceed?" on reversible work is a gate nobody asked for.
- The gate before an irreversible action, and for a product or preference call that no run can settle, is a different one and always holds, see [never-block-on-the-human](never-block-on-the-human.md).

**The test:** Is the agent waiting for an approval the owner did not ask for?
Then it proceeds.
Did the owner ask for a gate here?
Then it stops.
