# Autonomous run

You own the exit condition.
Define done, then drive to it without stopping.

## What must hold

- The exit condition was stated as a checkable predicate before the first iteration: the tests green, the reproduction fixed, every pull request of a list opened, a pixel diff of zero.
- The run wakes itself. An event to wait for (CI, a merge, a branch that moves) has a watcher that wakes the run when it happens, with a long heartbeat as a fallback. Without an event, a heartbeat is sized to when the result is worth checking again.
- Each iteration made the smallest change the evidence justified, checked it against the predicate, committed it when the predicate moved and discarded it when it did not. A belt-and-suspenders change that "might help" was reverted, not left to ride. The work is sequenced per the principle `sequence-verifiable-units`, each unit verified before the next and no batch of checks left for the end.
- What the run found on the way was handled by the run: a broken skill, a related bug, a flaky check, noise in a review, a failing tool, a forgotten follow-up, drift that could be fixed. Each fix outside the task went into a change of its own, per the principle `fix-debt-in-its-own-change`. No reversible work was parked for the operator, and no question was asked about it. The predicate stays the main drive, and the run returns to it after each side fix.
- Only three things reached the operator: an action the standing instructions always ask about, a product or preference call that no run can settle, and a real dead end.
- Every iteration has its row in the trail of `build:work-trace`: what changed, and whether the predicate moved.

## Proof owed

- The predicate met, shown by the check that defines it.

A plateau is not a stop.
Keep going, and change the approach to get past it.
Report a real dead end rather than spinning, and never relax the predicate to declare victory.

Then invoke `build:pull-request`.

**Reply:** the exit condition, the iterations run, what landed, what was discarded, and the final state of the predicate.
