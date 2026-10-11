# Prescribe proof, not steps

Anything written for an agent to follow states what must hold and what proof is owed, and gives steps only where they are facts the reader cannot derive.

**Why:** An agent plans and executes well, and a script of steps replaces its judgment with the author's guess about a situation the author never saw.
Steps go stale with every model and every change to the tree, and keeping them current is work that buys worse results.
A statement of what must hold stays true while the way to get there changes, and proof owed makes the result checkable by someone who did not watch the work.

**Pattern:**

- In a skill, a prompt for a subagent, an issue or a plan, write the outcome (what must hold when the work is done) and the evidence that shows it (the proof owed).
- Keep a step when it is a fact the reader cannot derive: the exact command of this repository, an order that an external system imposes, a trap that cost someone an hour.
- Delete a step the reader would take anyway. "Read the file before editing it" teaches nothing.
- State a constraint as a constraint (what must not change, what must not be touched), not as a sequence that happens to respect it.
- Proof is something a reviewer can rerun or read: a command with its output, a test that failed before and passes after, a transcript.

**The test:** Could a competent agent that ignored every step still tell, from this text alone, whether it succeeded?
If not, the text prescribes steps where it owes proof.
