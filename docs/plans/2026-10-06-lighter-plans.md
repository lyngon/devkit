# Lighter plans

## Design

### Goal

A plan holds only what its implementer cannot know or must not decide, so that the owner can read it at the first review gate and the planner stops spending the most capable model on text an implementer writes as well.
The owner gates plan (pull request 7) ran to 3,430 lines for 13 tasks: about 820 lines of complete bash, about 1,400 of dictated skill text with the old text quoted beside the new, and about 250 of the same version bump and commit steps repeated in ten tasks.
Its 13 task reviews found one real issue.
The decision is recorded in [ADR 0019](../adr/0019-plans-carry-decisions-and-facts-the-implementer-writes-the-tests-and-the-code.md), and the terms Plan, Acceptance line, Dictated text and Mandated check in [CONCEPTS.md](../../CONCEPTS.md).

### Approach

One standard for every plan.
The implementer is "a skilled developer who knows almost nothing about this repository's toolset or problem domain", and writes the tests and the code.
The plan lays out the order of the tasks and carries the project, toolset and domain facts that such a developer lacks.
It names no model tier and prefers no executor.

The planner applies one rule in both directions.
Every line in a task is something the implementer cannot know or must not decide; a line that is neither is cut.
A decision the implementer must not make that is left open, or a fact the implementer cannot know that is left out, is a placeholder.

These stay exact, because they are facts or decisions:

- the interfaces between tasks, and the file paths;
- the values the Design fixes (magic strings, version floors, formats);
- behaviour, as acceptance lines: one line per behaviour, edge behaviours included, each checkable on its own;
- dictated text: decision records, working rules, term definitions and protocol text;
- owner gates and mandated checks.

Everything else is the implementer's: the test code, the test cases, the implementation, descriptive prose (README sections, changelog entries, provenance record lines, examples).
Code in a plan is not banned; the rule above decides, and it leaves room for a few lines that state a toolset fact (an exact invocation, an option's syntax).

The alternatives (depth by implementer tier, a second pass that expands the plan before dispatch, tests pinned in the plan) are in ADR 0019 with the reasons they lost.

### Components

#### The plan skill

`plugins/build/skills/plan/SKILL.md` changes most.

The overview states the implementer assumption and the rule above, and drops "questionable taste" and "does not know good test design very well".
The "Bite-sized granularity" section goes; "Task right-sizing" stays as it is.

An ordinary task has no steps:

````markdown
### Task N: [Component name]

**Files:**

- Create: `<package>/src/exact/path/to/file.py`
- Modify: `<package>/src/exact/path/to/existing.py`
- Test: `<package>/tests/exact/path/to/test.py`

**Interfaces:**

- Consumes: [what this task uses from earlier tasks, with exact signatures]
- Produces: [what later tasks rely on, with exact names and types]

**Intent:** [What this task builds and why, and the toolset or domain facts the implementer cannot know.]

**Acceptance:**

- [One behaviour, checkable on its own, with exact values where the Design fixes them.]

**Commit:** `feat(scope): subject`
````

A task that dictates text adds two blocks before the commit subject:

````markdown
**States:**

- [A state or path the text is read in]: [the outcome the text must give there]

**Dictated text:**

In `path/to/file.md`, section "Heading", after the sentence that begins "Anchor words":

```markdown
The new text, word for word.
```
````

Dictated text is new text only, located by section and anchor sentence; the plan never quotes the text it replaces.
The States block is required when the dictated text is protocol text (text read on more than one path, as `build:delegate` already defines it for the state walk) and left out otherwise.
The planner checks its dictated text against each state before the handoff.

A task has steps only when it holds an owner gate or a mandated check.
It keeps the blocks above, and its steps hold what must happen in order: the failing run of each check, the work, the passing run, and the gate's steps as today.
A mandated check is for two cases.
The first is a string that a script reads or other text links to (a heading used as an anchor, a ledger line format, a version number a validator checks), where the presence of the exact string is the behaviour.
The second is a behaviour whose false green would be expensive.
Every mandated check is still proven both ways, with the expected output of both runs.

A rule that repeats in every task (a version bump with its changelog entry, a hook run) is stated once in Global Constraints and never as a step.
The commit is one line, the Conventional Commits subject, because its type and scope are decisions; there is no `git add` block.

The plan header's line for agentic workers names both executors without recommending one, and says that only gated and checked tasks have steps.
Review Focus becomes the input classes and failure modes the spec implies but no task's acceptance lines cover; each still gets its acceptance line in the task that owns the code.

"No placeholders" is reworded around the two-way rule.
Still failures: "TBD" and its kin; "add error handling", "add validation", "handle edge cases" (no input named, no outcome named); an acceptance line that cannot fail ("works correctly"); a line that bundles several behaviours; a value the Design fixes that is paraphrased or missing; "similar to Task N"; a name no Interfaces block defines; a check without a control; a gate missing a field.
No longer failures: a task without test code, a task without a code block.

The self-review changes with it:

- The placeholder scan uses the new list.
- A new item, the line test: read every task line by line against "cannot know or must not decide" and cut what fails.
- A new item, steps: an ordinary task written with steps is rewritten without them.
- A new item, size: a step-less task that passes about 30 lines, not counting its dictated blocks, is re-read against three questions: is it two tasks, is it doing design work the Design left open, is something stated that the implementer could decide. Dictated blocks and tasks with steps get no number. The 30 is a guess to tune from the first real plans.
- Type consistency checks the Interfaces blocks against each other.
- The dictated prose item also checks protocol text against each state in its States block.

The execution handoff gains three things.
It reports the plan's total lines and its longest task with the reason for its length.
It recommends `build:execute` when the plan has about five tasks or fewer and no owner gate the agent performs, and `build:delegate` otherwise.
When the plan has an owner gate the agent performs, the Inline option says that the code such a gate runs gets no independent review before the gate, so a pre-approved gate would pass on its `Expected:` line alone.

The skill's `description` and the `build` README stop saying "bite-sized, test-first tasks".

#### The delegate skill and its templates

In `plugins/build/skills/delegate/SKILL.md`, Model selection makes the mid tier the floor for the implementer and the reviewer of every plan task.
The cheapest tier keeps the batch of same-shape edits and single-file mechanical fix rounds.
The sentences "most implementation tasks are mechanical when the plan is well-specified" and "complete code means the cheapest tier" go.

The pre-flight scan's row per task checks the task's acceptance lines against its Interfaces block, and its dictated text against its States.

The implementer template (`references/implementer-prompt.md`) says:

- Build what the Intent and the acceptance lines require; the choices they leave open are the implementer's.
- Write a failing test for each acceptance line before the code, wherever the repository has a test surface for it.
- Place dictated text word for word.
- For a task with States, read the placed text in each state. When the text and a state disagree, the state wins: report BLOCKED with the state and the sentence, and never reword silently. The controller rules on it and ledgers the ruling, which is the existing route for a wrong plan.
- The report lists every acceptance line with the test that covers it and that test's RED and GREEN output, or the place in the diff that meets it and why no test could; and the command that runs the task's own test files.

The task reviewer template (`references/task-reviewer-prompt.md`) says:

- Spec compliance is a verdict per acceptance line: the test that covers it and whether that test would fail if the line were violated, or the place in the diff that meets it.
- A line with no such test is a Missing finding, and so is a line met only by a diff location where the repository has a test surface that could have covered it.
- The RED and GREEN output in the report is a claim. The reviewer runs the task's own test files once, with the command the report names, and never the whole suite; this replaces "do not re-run tests".
- Choices the plan leaves open are the implementer's and are not findings, unless the quality rubric calls the result a defect.
- For a task with States, a verdict of HOLDS or BROKEN per state, read from the whole file the dictated text sits in. A BROKEN state is an Important finding.

The skill's own text about reviewer inputs, the example workflow and the rationalizations follow these changes.

#### The execute skill

In `plugins/build/skills/execute/SKILL.md`, "the plan already did the thinking, execute it exactly" becomes "the plan carries the decisions; the tests and the code are yours".
The session model is mid tier or above, because below it the plan's assumption about its implementer does not hold.

The task loop distinguishes the two kinds of task.
In a step-less task the executor writes a failing test per acceptance line and then the code, under `practice:tdd`.
In a task with steps it works the steps in order and compares every `Expected:` line, as today.

The completion contract for a step-less task:

- every acceptance line has a test that ran in this task and was seen failing before the implementation existed, or, where the repository has no test surface for it, was checked against the diff;
- the final run passed (`task-done`, unchanged);
- every deviation has a `Ruling:` line.

There is no ledger line per acceptance line.
For a task with States the executor walks them after writing the text and ledgers the walk as `Task <N>: walked <state>: <outcome>; ...`, the form its fix pass already uses.
When the text and a state disagree, the state wins, and the smallest rewording that satisfies it is a ruling.

#### The reviewer template of the review plugin

`plugins/review/skills/request/references/code-reviewer.md` gains one instruction for a review whose requirements are a plan: check every task's acceptance lines on the branch as a whole (a later task may have broken an earlier one), and give HOLDS or BROKEN for every state of every States block, since the holes of pull request 7 sat between tasks.
The reviewer already receives the plan, so no placeholder is added.
Its Review Focus sentence says "no task's acceptance lines cover" where it says "the plan's tests do not exercise".

#### The approach skill

`plugins/discover/skills/approach/SKILL.md` gains one self-review bullet: the Design fixes every value an implementer must use exactly and names every edge behaviour, because the plan copies them and decides none.

#### Documents

- `shared/WORKFLOW.md`, in the architectural flow. Step 2 says what the plan holds (the tasks in order, with their interfaces, acceptance lines, dictated text, owner gates and mandated checks), and step 4 says the task reviewer gives a verdict per acceptance line.
- `plugins/build/README.md` gets a new `/build:plan` bullet and a pointer to ADR 0019 beside the other two.
- The provenance records of the five vendored skills touched (`plan`, `delegate`, `execute`, `request`, `approach`) list their local patches. `plan`'s "Why it is here" and `execute`'s first paragraph stop describing a fully specified plan.
- Each plugin's `CHANGELOG.md` and version follow the repository rule of one bump and one entry per commit with a visible change, so `build` rises by one minor version per such commit, and `review` and `discover` by one each.
- The `docs/TODO.md` entry and `docs/seed-prompts/lighter-plans.md` are removed in the last commit.

No script changes.
`task-brief` extracts a step-less task whole, including a dictated block that holds headings and nested fences, and `task-start` only wraps it.

### Data flow

The Design fixes values and edge behaviours.
The planner copies them into acceptance lines and dictated text, and adds the interfaces and the order.
`task-brief` cuts one task and the Global Constraints into a brief.
The implementer turns each acceptance line into a failing test and then into code, and reports line by line.
The task reviewer returns a verdict per line and per state; the controller ledgers the result.
The final reviewer reads the plan and checks every line and every state on the whole branch.
Inline, the executor plays the implementer and the per-task reviewer's part is left to its own tests and walks, so the final review is the first independent check.

### Error handling

When dictated text and a state disagree, the state wins.
Under `build:delegate` the implementer reports BLOCKED and the controller rules; inline, the executor rules.
Either way the ruling is ledgered and reaches the pull request.

When no test can run an acceptance line, the implementer names the place in the diff that meets it.
The reviewer accepts that only where the repository has no test surface for the line.

When the plan left out a fact, the implementer reports NEEDS_CONTEXT and the controller answers from the Design.
When the Design is silent too, the answer is a ruling.

The executors still run a plan written before this change.
A task with steps keeps the `Expected:` comparison whatever its kind, and the per-line verdict applies only to a task with an Acceptance block; a task without one is reviewed against its text, as today.

### Testing

- `devenv test` passes on every commit: the validators, the hooks and the script tests.
- One regression test in `plugins/build/tests/scripts.sh`: `task-brief` on a step-less task with a dictated block that holds a heading and a nested fence, followed by another task, prints the task whole and nothing after it. The design relies on this behaviour and nothing pins it today.
- A rehearsal in a throwaway repository under `tmp/`, with nested headless sessions that load this worktree's plugins, as the owner gates work did. It runs right after the plan skill, the delegate skill and its two templates have landed, and before the rest. A small Design with three tasks (one of code, one with a mandated check, one that dictates protocol text with States) goes through `build:plan` and then `build:delegate` on a mid-tier model. It checks that the plan's ordinary tasks have no steps and no test code, that the handoff reports the size, that the implementer's report maps each acceptance line to a test, that the task reviewer returns a verdict per line and per state, and that the ledger shows three completed tasks. A departure is fixed in the file that owns the sentence, one commit per defect, and the rehearsal runs again. Its evidence is the body of a record commit.
- This work's own plan follows this Design where the installed `build:plan` differs, as the first real plan of the new kind.

### Out of scope

- An adversarial design review before planning, one mechanism per plan, an earlier rehearsal as a rule, and a rehearsal of `build:execute`: all four are deferred in `docs/TODO.md`.
- A script that measures a plan's size; the planner counts lines in its self-review.
- A task review that scales or is skipped per task, and a review before each gate under inline execution. The executor choice is the only lever.
- A field in the plan for the model tier or the executor.
- Any change to the owner gate protocol or to the scripts.
