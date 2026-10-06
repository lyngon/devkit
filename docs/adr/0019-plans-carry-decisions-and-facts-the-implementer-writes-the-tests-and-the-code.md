# Plans carry decisions and facts, and the implementer writes the tests and the code

The vendored plan skill spelled out complete code, every test and every command in every task, so that an implementer with no judgment could transcribe it.
The owner gates plan ran to 3,430 lines for 13 tasks, more than the owner could review, and its 13 task reviews found one real issue while the design-level holes surfaced only in the whole-branch review.
A plan now holds only what its implementer cannot know or must not decide: the order of the tasks, the interfaces between them, the values the design fixes, one acceptance line per behaviour, dictated text where the wording is the decision, owner gates and mandated checks.
The implementer is assumed to be a skilled developer who knows nothing of the repository, and writes the tests and the code; there is one standard for every plan, which names no model tier and prefers no executor.

## Considered options

- Depth by tier: complete code for a cheap implementer, intent for a mid-tier one. The planner still spends the most capable model's output so that a cheaper model can transcribe it, and the plan would have to know its executor, which the owner chooses only after reading it.
- Two passes: a short plan at the first review gate, expanded to complete code before each dispatch. The expansion costs the same later and nobody reviews it.
- Tests pinned in the plan, as code or as a list of cases with inputs and outputs. A skilled developer designs tests; the plan pins the behaviour, and the task reviewer checks that a test covers each acceptance line and would fail if the line were violated.
- Keep complete plans. The numbers above are the case against it.

## Consequences

- The mid tier is the default implementer in `/build:delegate`; the cheapest tier keeps only batches of same-shape edits and mechanical fix rounds. Planning costs less of the most capable model, and each task costs more of the mid tier.
- The design carries more weight: a value or an edge behaviour it does not fix is one the planner must decide, so `/discover:approach` checks for them.
- The task review does real work: a verdict per acceptance line, where it used to compare a transcription with its source. `/build:execute` has no such review, so a plan with an owner gate the agent performs recommends `/build:delegate`.
- Dictated text that an agent follows as a procedure lists the states it is read in, and the planner, the implementer and the reviewers check it against each one, because no test runs such text.
- This departs from the upstream skill's central rule (complete code in every step, no step without a code block). When the vendored skill is compared with upstream, that rule is not carried back.
