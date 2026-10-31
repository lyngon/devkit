# Bug fix

You own the task, the review and the proof.
Delegate the investigation and the fix to subagents, and stay the lead.

Be scientific.
Every shipped line traces to runtime evidence.
A belt-and-suspenders change that "might help" is a hypothesis, not a fix, and it does not ship.
When evidence refutes a hypothesis, revert what it motivated.
The smallest change that the evidence justifies ships, and nothing more.

## What must hold

- You reproduced the bug yourself, on the surface where it was reported, even when a debugging protocol says to ask the operator to reproduce it. Ask the operator only with a stated, specific reason why you cannot reach that surface, and only after driving it as far as it goes. When it will not reproduce directly, synthesize the trigger, tighten the conditions, or instrument until it fires.
- The cause was found by elimination. The candidate hypotheses were seeded by subagents that invoked `discover:how` over the subsystem and `discover:why` for the history of a regression. Each pass took the split that cut the most of the remaining problem, got runtime evidence and ruled out what it could. Where the state of the program was unclear, logging or instrumentation was read as the code ran, not guessed. The surviving mechanism was confirmed by runtime evidence before the fix was designed.
- A fix that crosses a function boundary was designed through `build:architect`. A `build:implementer` delegate wrote the fix and its test, with a specific scope, however small the fix is. No reason to skip the delegate counts, because the gain is the separation of writing from review, not lines saved.
- When the bug has a cheap local test path, the reproduction is a test written per `build:tdd`, and it stays as a regression test. When the test would be expensive, heavy on integration or unclear, the closest executable check takes its place.

## Proof owed

- The original reproduction passes, on the same surface. An inconclusive result, or one from another surface, is not a pass, and the reply says so. Unit tests show how a branch behaves, not that the bug is gone.
- The failing reproduction is committed before the fix, so the history shows it fail and then pass. This is the canonical order of the principle `sequence-verifiable-units`: the failing test first, the fix on top.

Then invoke `build:pull-request`.

**Reply:** what was broken, the root cause, the fix, and how you verified it, with the output of the reproduction failing and then passing, verbatim.
