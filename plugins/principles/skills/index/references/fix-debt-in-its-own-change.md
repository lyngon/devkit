# Fix debt in its own change

Debt found is fixed in the same session in its own change when the fix can be proven, and otherwise becomes an issue with the evidence.

**Why:** Debt that is only noted is paid by every later session, which trips over it or copies it.
The session that found it holds the context that makes the fix cheap, and that context is gone when the session ends.
A fix folded into an unrelated change hides in its diff, cannot be reverted alone and makes the review answer two questions at once.

**Pattern:**

- Debt is what makes the right thing harder or the wrong thing pass: a missing check, a misleading name, a duplicated rule, a flaky test. A design you would have chosen differently is not debt.
- Finish or park the work at hand, then fix the debt on a branch of its own, as a pull request of its own.
- When the debt blocks the work at hand, fix it first, in its own change, and build on that.
- "Can be proven" means a run shows that the fix works: a test, the full check, the output of the real command. With no proof within reach, do not guess at a fix.
- An issue for debt states what was found, where, and the evidence (the command and its output, the file and the line), so that whoever picks it up does not have to find it again.

**The test:** At the end of the session, is every piece of debt it found either a change of its own with proof, or an issue with evidence?
"I noticed X" in a summary is neither.
