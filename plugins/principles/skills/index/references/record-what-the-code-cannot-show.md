# Record what the code cannot show

Text enters a steering document or a code comment only through the admission test, and a decision that passes it is recorded in the same change.

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

**Why:** An agent reads code well, so a steering document or a comment that repeats the code only adds a second place that can be wrong.
What the code cannot show (intent, principles, terms, decisions) is lost unless someone writes it down, and the next agent then undoes the decision in good faith.
A decision recorded later, in another change, is recorded from memory or not at all.

**Pattern:**

- The principle covers steering documents and comments in code. Text written for another reader is outside it, such as a README, a changelog, a provenance record or user documentation.
- Run the test on the text before writing it. Text that fails stays out, however true it is.
- Deducible is not the same as cheap. When the code shows something only to a reader who opens five files, make the code say it locally or write the check.
- Put what passes where its kind lives: purpose in `INTENT.md`, a term in `CONCEPTS.md`, a repository principle in `.claude/rules/`, a decision in `docs/decisions/`.
- A comment passes when it says what its code cannot show: a constraint from outside, a reason, an invariant that no check holds. A comment that restates its code fails. One that would explain a surprise in your own code is the case of [reshape-instead-of-commenting](reshape-instead-of-commenting.md).
- Record a decision in the change that makes it, with its reason, in a file named after the decision.
- When a check comes to carry a decision, delete the record.

**The test:** Would a competent agent who opened only the files this change touches undo the decision, or contradict the comment, wrongly, with every check still green?
If yes, the text is owed in this change.
If a check could go red instead, the check is owed.
