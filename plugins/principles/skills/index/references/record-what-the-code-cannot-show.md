# Record what the code cannot show

Prose enters the tree only through the admission test, and a decision that passes it is recorded in the same change.

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

**Why:** An agent reads code well, so prose that repeats the code only adds a second place that can be wrong.
What the code cannot show (intent, principles, terms, decisions) is lost unless someone writes it down, and the next agent then undoes the decision in good faith.
A decision recorded later, in another change, is recorded from memory or not at all.

**Pattern:**

- Run the test on prose before writing it. Text that fails stays out, however true it is.
- Deducible is not the same as cheap. When the code shows something only to a reader who opens five files, make the code say it locally or write the check.
- Put what passes where its kind lives: purpose in `INTENT.md`, a term in `CONCEPTS.md`, a repository principle in `.claude/rules/`, a decision in `docs/decisions/`.
- Record a decision in the change that makes it, with its reason, in a file named after the decision.
- When a check comes to carry a decision, delete the record.

**The test:** Would a competent agent who opened only the files this change touches undo the decision, wrongly, with every check still green?
If yes, the record is owed in this change.
If a check could go red instead, the check is owed.
