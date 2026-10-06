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
### Task N `task-slug`: [Component name]

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

Every task heading carries a slug beside its number, kebab-case and unique in the plan, and so does every step, unique in its task; the step of an owner gate carries the gate's ID and no other slug.
Number and slug together are the task's label, and whatever refers to a task or a step names both, so that a wrong number shows.

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

#### Labels in the scripts and the protocol

The executors name a task by its label everywhere: `Task 3 implementer: complete (...)` in the ledger, `task-3-implementer-brief.md` for its brief, and the same for its report, its test log, a pause line, a pause commit and a dispatch description.
The slug is in backticks in Markdown, as the heading has it, and bare in the ledger, in a shell argument, in a commit message and in a file name.
A backtick inside a double-quoted shell argument is a command substitution, which would drop the slug or be refused in a session isolated in a worktree; gate IDs are bare in the ledger for the same reason.

- `task-brief` reads the slug from the heading ``### Task N `slug`: Title``, names the brief after it, and prints the label with `--label`. It refuses a slug that is not kebab-case, the slugs `pre-gate` and `post-gate` (they would read as a part), and a slug two tasks share.
- `task-start` prints the label, and `task-done` writes the completion line and names its test log under it. Both take it from `task-brief --label`, so one parser decides what a task is called.
- The delegate skill, the execute skill, the owner gate protocol and the four prompt templates write `<label>` (the templates `[LABEL]`) wherever they wrote `Task <N>` or `Task N`, and derive a report's name from its brief's.
- The number identifies the task and the slug catches a wrong number. A ledger line whose number and slug do not belong to one heading is not read as progress until `git log` shows the commits it names.
- A plan whose headings have no slug keeps `Task N` and today's file names, so a plan written before this change, or a run in flight, reads as before.

`execution-status`, `workspace`, `review-package` and `pin` do not change: they treat the ledger and the resume point as text.
The owner gate protocol changes only in how it names a task and a step.

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
For a task with States the executor walks them after writing the text and ledgers the walk as `<label>: walked <state>: <outcome>; ...`, the form its fix pass already uses.
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

Three scripts change, as "Labels in the scripts and the protocol" says.
What `task-brief` already does is kept and pinned: it extracts a step-less task whole, including a dictated block that holds headings and nested fences, finds a task by its number whether or not a slug follows it, and splits a gated task whose other steps carry slugs.

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
- Script tests in `plugins/build/tests/scripts.sh`, written first: the slug, the label, the file names and the refusals of `task-brief`, and the label in `task-start` and `task-done`. They also pin what the design relies on and nothing tests today: `task-brief` on a step-less task with a dictated block that holds a heading and a nested fence, and on a gated task whose other steps carry slugs.
- One mandated check, a count of the places where the executors' text still names a task by its number alone: 37 before the change, 0 after it.
- A rehearsal in a throwaway repository under `tmp/`, with nested headless sessions that load this worktree's plugins, as the owner gates work did. It runs right after the plan skill, the delegate skill and its two templates have landed, and before the rest. A small Design with three tasks (one of code, one with a mandated check, one that dictates protocol text with States) goes through `build:plan` and then `build:delegate` on a mid-tier model. It checks that the plan's ordinary tasks have no steps and no test code, that the handoff reports the size, that the implementer's report maps each acceptance line to a test, that the task reviewer returns a verdict per line and per state, and that the ledger shows three completed tasks. A departure is fixed in the file that owns the sentence, one commit per defect, and the rehearsal runs again. Its evidence is the body of a record commit.
- This work's own plan follows this Design where the installed `build:plan` differs, as the first real plan of the new kind.

### Out of scope

- An adversarial design review before planning, one mechanism per plan, an earlier rehearsal as a rule, and a rehearsal of `build:execute`: all four are deferred in `docs/TODO.md`.
- A script that measures a plan's size; the planner counts lines in its self-review.
- A task review that scales or is skipped per task, and a review before each gate under inline execution. The executor choice is the only lever.
- A field in the plan for the model tier or the executor.
- Any change to the owner gate protocol beyond how it names a task and a step, and any change to `execution-status`, `workspace`, `review-package` or `pin`.

## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` or `build:execute` to implement this plan task by task. A task has steps (checkbox `- [ ]` syntax) only where it holds an owner gate or a mandated check.

**Goal:** `build:plan` writes plans that hold only what an implementer cannot know or must not decide, and the executors, the reviewers and the workflow document work from such plans.

**Architecture:** The plan skill defines the task shape (Files, Interfaces, Intent, Acceptance, and States with Dictated text where wording is the decision); the implementer template turns acceptance lines into tests, and the task reviewer and the final reviewer give verdicts per line and per state. Three scripts learn a task's label (its number and slug), and the executors' text names a task by it in the ledger, the briefs and the dispatches. A rehearsal in a throwaway repository proves the skill text once the plan and delegate skills have landed.

**Tech stack:** Markdown skill text and prompt templates, the bash script tests in `plugins/build/tests/scripts.sh`, devenv with prek hooks, nested headless `claude -p` sessions for the rehearsal.

**Spec:** The `## Design` section of this file.

### Owner Gates

None.

### Global Constraints

- A commit with a user-visible change to a plugin bumps `version` in that plugin's `.claude-plugin/plugin.json` by the commit's own semver level (`feat` minor, `fix` patch) and adds an entry `## <version> - <date of the commit>` at the top of the plugin's `CHANGELOG.md`, in the same commit. A `test` or `docs(todo)` commit bumps nothing. These files are touched by rule and are not listed in a task's Files block.
- A commit that changes a vendored skill adds a line under "Local patches" in that skill's `UPSTREAM.md`, in the same commit. Also not listed per task.
- Skill text, templates and `shared/` documents ship to every Lyngon repository: they never name this repository's layout or its ADRs, they name model tiers ("mid-tier", "most capable") and never a model, and they say "the user", with "owner" only in "owner gate". A plugin's `README.md` may link an ADR.
- The terms are "acceptance line", "dictated text", "mandated check" and "plan". Never "light plan" or "lighter plan" in anything that ships.
- Markdown: one sentence per line, no em or en dashes, no curly quotes, every fenced block names its language. Template files keep the heading case and the four-space indentation of the lines around an edit.
- Dictated text is placed word for word. Where it replaces text, the section and the anchor name what goes; nothing else in the file changes unless an acceptance line says so.
- `shared/WORKFLOW.md` is edited in `shared/`, never through a symlink in a plugin.
- Among the scripts, only `task-brief`, `task-start` and `task-done` change; `execution-status`, `workspace`, `review-package` and `pin` do not.
- A task's label is the word `Task`, its number and its slug: in backticks in Markdown (``Task 4 `task-labels` ``), bare in the ledger, in a shell argument, in a commit message and in a file name (`Task 4 task-labels`).
- The run of this plan writes its own ledger lines under the label from the first line on (`Task 1 brief-slugs: complete ...`), whichever version of the skill text it has loaded, so that its ledger has one format.
- Hook evidence is the output of `prek run --files <the files the task changed>`, run after the last change. `bash plugins/build/tests/scripts.sh` runs the script tests on their own; `devenv test` is the full check.
- Commits are Conventional Commits with the subject the task gives, on `feat/lighter-plans`, and never mention an agent.

### Review Focus

- A dictated block that holds a fence or a heading, fenced too short: the brief must not end inside it. Pinned in Task 1 `brief-slugs`, the extraction, and Task 3 `plan-skill`, the fencing rule.
- A plan written before this change, with steps and code, no Acceptance block and no slugs, run by the new scripts and executors: it must still run, under `Task N` and today's file names. Pinned in Tasks 1 `brief-slugs` and 2 `label-scripts` and in the States of Tasks 4 `task-labels`, 5 `implementer`, 6 `task-reviewer` and 8 `execute-skill`.
- A label that passes through a shell (a ledger append, `execution-status write`, `git commit -m`): a backtick there is a command substitution, so the slug is bare. Pinned in the States of Task 4 `task-labels`.
- A ledger line whose number and slug do not belong to one heading, after a heading changed in the middle of a run: it must not be read as progress, nor the task run twice. Pinned in the States of Task 4 `task-labels`.
- A task whose acceptance lines no test can run, executed inline: `task-done` still needs a command. Pinned in Task 8 `execute-skill`.

### Task 1 `brief-slugs`: `task-brief` names a brief by its slug and prints the label

**Files:**

- Modify: `plugins/build/skills/delegate/scripts/task-brief`
- Modify: `plugins/build/tests/scripts.sh`

**Interfaces:**

- Consumes: nothing.
- Produces: a task heading ``### Task N `slug`: Title`` gives the task the slug `slug`, and any other task heading gives it none; `task-brief PLAN_FILE N --label` prints the label on stdout, `Task N slug`, or `Task N` without a slug, and writes no file; the default brief names are `task-N-slug-brief.md`, `task-N-slug-pre-gate-brief.md` and `task-N-slug-post-gate-brief.md`, and without a slug they are as today.

**Intent:** Every later task relies on two things that `task-brief` does not do or does not pin today.
It must extract a task that has no `- [ ] **Step` line, which nothing tests: the existing fixture's tasks all have steps.
And it must read the slug from a task heading, so that the brief's file name and the ledger carry it; `--label` is how `task-done` and the executors learn the label without parsing the plan a second way.
The script's awk pass already tracks fences and finds the heading; the slug comes from the same pass.
The tests go in the `task-brief` section of the script tests, in the style of the checks around them (`check`, `equals`, `contains`, `lacks`, the `fixture` and `brief` helpers).

**Acceptance:**

- For a task with no step line, `task-brief` exits 0 and the brief holds every line of the task, from its heading to its `**Commit:**` line.
- In that brief, a `##` heading and a three-backtick fence inside a dictated block fenced with four backticks are intact, and the brief does not end at that heading.
- That brief holds no line of the task that follows and no line of a trailing `## Execution status` section, and ends with the Global Constraints section.
- `--label` prints exactly `Task 3 rate-limiter` for the heading ``### Task 3 `rate-limiter`: Title`` and `Task 3` for `### Task 3: Title`, exits 0, and leaves the workspace without a brief.
- `--label` works for a task with an owner gate without `--part`, and exits 3 for a task the plan does not have.
- `--label` together with `--part` or an OUTFILE is a usage error, exit 2.
- Without an OUTFILE, the brief of a task with the slug `rate-limiter` is `task-3-rate-limiter-brief.md`, and its parts are `task-3-rate-limiter-pre-gate-brief.md` and `task-3-rate-limiter-post-gate-brief.md`.
- A task without a slug keeps `task-3-brief.md` and the part names of today.
- A slug that does not match `^[a-z0-9]+(-[a-z0-9]+)*$` is refused: exit 3, a message on stderr that names the slug, nothing written.
- The slugs `pre-gate` and `post-gate` are refused in the same way.
- A slug that two task headings of the plan share is refused in the same way, and a heading inside a fence does not count as one of them.
- A task is found by its number whether or not a slug follows it, and asking for Task 1 never returns Task 12.
- For a task with an owner gate whose other steps carry a slug after their number (``- [ ] **Step 1 `save-plan`: Title**``), `--part pre-gate` ends at the gate block and `--part post-gate` starts at it.
- The script's header comment documents the slug, `--label` and the file names.
- Each new check was seen failing: before the script changed, or, for behaviour the script already has, against a fixture altered so that the property does not hold. The report shows those runs.
- `bash plugins/build/tests/scripts.sh` exits 0 and prints no `FAIL:` line.

**Commit:** `feat(build): name a task's brief by its slug and print its label`

### Task 2 `label-scripts`: `task-start` prints the label and `task-done` ledgers under it

**Files:**

- Modify: `plugins/build/skills/execute/scripts/task-start`
- Modify: `plugins/build/skills/execute/scripts/task-done`
- Modify: `plugins/build/tests/scripts.sh`

**Interfaces:**

- Consumes: `task-brief PLAN_FILE N --label` of Task 1 `brief-slugs`.
- Produces: `task-start` prints a third line, `label: <label>`; `task-done` appends `<label>: complete (commits <base7>..<head7>, tests: <command> → <result>)` to the ledger and keeps the test output in `task-N-slug-tests.log`.

**Intent:** The inline executor's two scripts call a task `Task N` today.
They take the label from `task-brief --label`, so that one parser decides what a task is called.
Both call `task-brief` through `bash`, as they call the other delegate scripts.

**Acceptance:**

- `task-start PLAN_FILE N` prints `brief:`, `base:` and `label:` in that order; the label line is `label: Task 3 rate-limiter` for a task with that slug and `label: Task 3` for one without, and it is the same with `--part`.
- For a task with a slug, `task-done` appends a line that starts with `Task 3 rate-limiter: complete (commits` and writes the test output to `task-3-rate-limiter-tests.log`.
- For a task without a slug, the ledger line and the log name are exactly what they are today.
- A failing test command still records nothing, and its message on stderr names the task by its label.
- When `task-brief` refuses the task (a malformed slug, a task the plan does not have), `task-done` exits non-zero before it runs the test command and records nothing.
- `bash plugins/build/tests/scripts.sh` exits 0 and prints no `FAIL:` line.

**Commit:** `feat(build): start and complete a task under its label`

### Task 3 `plan-skill`: The plan skill writes decisions and facts

**Files:**

- Modify: `plugins/build/skills/plan/SKILL.md`
- Modify: `plugins/build/README.md`

**Interfaces:**

- Consumes: the slug rules of Task 1 `brief-slugs` (kebab-case, unique among the plan's tasks, never `pre-gate` or `post-gate`).
- Produces: the task blocks that Tasks 5 `implementer`, 6 `task-reviewer`, 8 `execute-skill` and 9 `final-reviewer` read by name: `**Intent:**`, `**Acceptance:**`, `**States:**`, `**Dictated text:**`, `**Commit:**`; the heading ``### Task N `slug`: Title``; step lines ``- [ ] **Step N `slug`: Title**``, only in a task with an owner gate or a mandated check, with the owner gate marker spelled as before; the recommendation rule "about five tasks or fewer, and no owner gate the agent performs", which Task 11 `workflow` repeats.

**Intent:** The Design's "The plan skill" section, as skill text.
The dictated blocks below are the whole change to `SKILL.md`; everything they do not name stays, including "Where the plan lives", "Scope check", "File structure", "Task right-sizing" and "Owner gates".
`SKILL.md` holds fenced examples that hold fences, so check that every block you place closes where it should.

**Acceptance:**

- `SKILL.md` has no "Bite-sized granularity" section, and nowhere asks for test code, complete code, a code block per step or steps of "two to five minutes".
- The self-review list is numbered 1 to 9 without a gap, and items 1 and 2 and the item "Owner gates" keep their present text.
- Every link in `SKILL.md` resolves, `[Owner gates](#owner-gates)` and `[WORKFLOW.md](WORKFLOW.md)` included.
- The `/build:plan` bullet of `plugins/build/README.md` describes a plan as the tasks in order with their interfaces, acceptance lines and dictated text, written for an implementer who writes the tests and the code, and no longer says "bite-sized, test-first".
- That README names ADR 0019 beside ADR 0016 and ADR 0018, with a relative link to `docs/adr/0019-plans-carry-decisions-and-facts-the-implementer-writes-the-tests-and-the-code.md`.
- "Why it is here" in `plugins/build/skills/plan/UPSTREAM.md` no longer credits the task shape of five steps with expected output, and "Local patches" says that the skill departs from upstream's rule of complete code in every step.

**States:**

- The planner writes a task of code: no steps, an Acceptance block with one line per behaviour, no test code.
- The planner writes a task that dictates a decision record or a term: a Dictated text block located by file, section and anchor, and no States block.
- The planner writes a task that dictates protocol text: a States block as well, and self-review item 8 reads the text in each state.
- A dictated block holds a fence or a heading: its own fence is longer, so the brief is not cut.
- The planner writes a task with a mandated check: steps with the failing run, the work and the passing run, every run with its `Expected:` line.
- The planner writes a task with an owner gate: steps as "Owner gates" says, with Intent and Acceptance only for work the steps leave open; the gate's marker is spelled as before and its ID is its slug, and the other steps carry their own.
- The planner refers to a task or a step, anywhere in the plan: by its label, number and slug together.
- An executor asks for a task by its number: the heading still begins `### Task N` followed by a space, so the task is found.
- The handoff with no execution method supplied: the first message, with the size line and a recommendation by the rule.
- The handoff with a method supplied: the second message, with the size line and no recommendation.
- A plan with an owner gate the agent performs: `build:delegate` is recommended, and the inline warning is in the first message, and in the second when the method is `build:execute`.
- The spec came from elsewhere than `discover:approach`: every rule says "the spec", so it applies unchanged.

**Dictated text:**

In `plugins/build/skills/plan/SKILL.md`, the frontmatter's `description` becomes:

```yaml
description: >-
  Write an implementation plan from a settled design: the tasks in order, each with
  its interfaces, its acceptance lines and any dictated text, appended as the Plan
  section of the design file under docs/plans/, and hand it to build:delegate or
  build:execute. Use when a design or spec exists and no code has been touched: "the
  design is settled, write the implementation plan", "write the plan", "plan the
  implementation". Not for design questions (that is discover:approach) and not for
  fixes too small to need a plan.
```

The body of the section "Overview" becomes:

```markdown
Write a plan for a skilled developer who knows almost nothing about this repository's toolset or problem domain.
The implementer writes the tests and the code.
The plan lays out the tasks in order and carries what such a developer cannot know or must not decide:

- Cannot know: the files and where they go, the interfaces neighbouring tasks rely on, the repository's commands, and the facts of its toolset and domain.
- Must not decide: the values the spec fixes, the behaviour (as acceptance lines), the wording of dictated text, owner gates and mandated checks.

Every line in a task is one of these, and a line that is neither is cut.
There is one standard for every plan: it names no model tier and reads the same for either executor.
DRY. YAGNI. One commit per task.

The flow this skill sits in, from `discover:approach` to `build:finish` and the user's two review gates, is in [WORKFLOW.md](WORKFLOW.md).
```

The section "Bite-sized granularity" is removed.

In "Plan section header", inside the header template, the line that begins "> **For agentic workers:**" becomes:

```markdown
> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` or `build:execute` to implement this plan task by task. A task has steps (checkbox `- [ ]` syntax) only where it holds an owner gate or a mandated check.
```

In the same template, the bracketed text under "### Global Constraints" becomes:

```markdown
[The spec's project-wide requirements: version floors, dependency limits, naming and copy rules, platform requirements. One line each, with exact values copied verbatim from the spec. A rule that repeats in every task (a version bump with its changelog entry, a hook run) goes here once and never into a task. Every task's requirements implicitly include this section.]
```

and the bracketed text under "### Review Focus" becomes:

```markdown
[The five input classes or failure modes the spec implies but no task's acceptance lines cover that are most likely to bite a person using this software. One line each, naming the input or condition and the behaviour a reasonable person would expect, most likely first. The spec is a vision document: it says what the software must do, not everything it will meet, and its silence on an input is not permission for that input to break the program. Write the list here, once, with the spec in front of you. Then, for each line, add the acceptance line that pins it to the task that owns the code.]
```

The section "Task structure" becomes, heading included:

`````markdown
## Task structure

An ordinary task has no steps:

```markdown
### Task N `task-slug`: [Component name]

**Files:**

- Create: `<package>/src/exact/path/to/file.py`
- Modify: `<package>/src/exact/path/to/existing.py`
- Test: `<package>/tests/exact/path/to/test.py`

**Interfaces:**

- Consumes: [what this task uses from earlier tasks, with exact signatures]
- Produces: [what later tasks rely on: exact function names, parameter and return types. A task's implementer sees only their own task; this block is how they learn the names and types neighbouring tasks use.]

**Intent:** [What this task builds and why, and the toolset or domain facts the implementer cannot know.]

**Acceptance:**

- [One behaviour, checkable on its own, with exact values where the spec fixes them.]

**Commit:** `feat(scope): subject`
```

The paths above are illustrations; the repository's layout decides.

- The heading carries the task's number and its slug: kebab-case, one to three words, unique in the plan, and never `pre-gate` or `post-gate`.
  Number and slug together are the task's label.
  Refer to a task by its label, as in ``Task 3 `rate-limiter` ``, in the plan and in everything written about it, so that a wrong number shows.
  The executors name the task's brief and its ledger lines by the label.
- **Acceptance** holds one line per behaviour, edge behaviours included.
  Each line can fail on its own: a reviewer can name the test that covers it, or the place in the diff that meets it, without reading another line.
  The implementer writes a failing test for each line and then the code; the plan holds no test code and no list of test cases.
- **Intent** says what the task builds and why in a few sentences, and gives the facts a skilled developer new to the repository lacks.
  Code belongs here only as such a fact, a few lines at most (an exact invocation, an option's syntax), never as the implementation.
- **Commit** is the Conventional Commits subject, because its type and scope are decisions.
  One commit per task on the feature branch, one concern per commit; a task may span several commits when the plan gives a subject for each.
  Every task ends with at least one commit; a task whose work lies outside the repository ends with a record commit, as a task with an owner gate does.
  Never commit on main.

### Dictated text

Text whose wording is the decision is dictated word for word: a decision record, a working rule, a term's definition, and protocol text.
Protocol text names states and the events that move between them, or states a rule that holds across steps: a procedure with gates, pauses and resumes, a ledger's line formats and what reads them, a prompt template with a variant per case.
It is recognized by a sentence that is read on more than one path.
Descriptive prose (a README section, a changelog entry, an example) is the implementer's to write from the Intent.

A task that dictates text adds these blocks before its commit subject:

````markdown
**States:**

- [A state or path the text is read in]: [the outcome the text must give there]

**Dictated text:**

In `path/to/file.md`, section "Heading", after the sentence that begins "Anchor words":

```markdown
The new text, word for word.
```
````

- Dictate the new text only, and locate it by file, section and anchor sentence.
  Never quote the text it replaces.
- Fence every dictated block, with a fence longer than any fence inside it.
  The executors cut a task's brief at the next heading outside a fence, so an unfenced heading in dictated text ends the brief early.
- **States** is required for protocol text and left out otherwise: every state and path that reads the text, each with the outcome the text must give there.
  No test runs such text, so the states are what it is checked against: by you before the handoff, by the implementer when placing it, and by the reviewers.
  When the text and a state disagree during execution, the state wins; the executor rules on the wording and records the ruling.

### Tasks with steps

A task has steps only when it holds an owner gate or a mandated check.
It keeps its Files and Interfaces blocks, and Intent and Acceptance for the work its steps leave to the implementer.
Its steps come after those blocks and hold what must happen in order, in checkbox syntax:

```markdown
- [ ] **Step 1 `check-fails`: Show the check failing**

Run: `<the check's command>`
Expected: `<its exact output while the property does not hold>`

- [ ] **Step 2 `work`: Do the work**

Build what the Intent and the acceptance lines require.

- [ ] **Step 3 `check-passes`: Show the check passing**

Run: `<the check's command>`
Expected: `<its exact output once the property holds>`
```

Every step that runs a command has an `Expected:` line.
Every step carries a slug after its number, unique in its task; the step of an owner gate carries the gate's ID in its marker and no other slug.
The task keeps its commit subject unless a step makes the commit, as the record commit of an owner gate does.
The steps of a task with an owner gate are in [Owner gates](#owner-gates).
`````

In "Checks and commands", after the first paragraph (it ends with the sentence that begins "A check seen only one way"), add this paragraph:

```markdown
A mandated check is a command whose exact output the plan pins, and it puts steps into its task, so use one in two cases only.
The first is a string that a script reads or that other text links to (a heading used as an anchor, a ledger line format, a version number a validator checks), where the presence of the exact string is the behaviour.
The second is a behaviour whose false green would be expensive.
Everything else is an acceptance line, which the implementer covers with a test.
```

The section "No placeholders" becomes, heading included:

```markdown
## No placeholders

A placeholder is a decision the implementer must not make, left open, or a fact the implementer cannot know, left out.
These are plan failures; never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling", "add validation", "handle edge cases": no input is named and no outcome
- An acceptance line that cannot fail ("works correctly", "is robust"), or one that bundles several behaviours
- A value the spec fixes that is paraphrased or missing
- "Similar to Task N" (repeat what the task needs; its implementer sees only their own task)
- A name, type or signature that no Interfaces block defines
- Dictated protocol text without its States block
- A check without a control: a mandated script or command shown passing but never shown failing when its property does not hold
- A gate missing a required field, or an owner action anywhere but at a gate inside a task

A task without test code or without a code block is not a placeholder: the implementer writes both.
The opposite failure is a line the implementer could have decided: test code, an implementation, the old text beside the new, a rule repeated in every task.
Cut it.
```

In "Self-review", items 3 to 6 of the numbered list are replaced by the six items below, and the item "Owner gates" becomes item 9:

```markdown
3. **The line test.** Read every task line by line: is this something the implementer cannot know or must not decide?
   Cut what is neither.
   An ordinary task written with steps is rewritten without them.
4. **Size.** Count the lines of every task without steps, leaving out its dictated blocks.
   One that passes about 30 lines is re-read against three questions: is it two tasks, is it doing design work the spec left open, is something stated that the implementer could decide.
   Dictated blocks and tasks with steps get no number; their content is exact by requirement.
   Note the lines of the whole `## Plan` section and the longest task with the reason for its length; the handoff reports them.
5. **Type consistency.** Do the names, types and signatures in every Consumes line match the Produces line they come from?
   A function called `clearLayers()` in Task 3 `layers` but `clearFullLayers()` in Task 7 `render` is a bug.
   Does every reference to a task or a step give the number and the slug that its heading has?
6. **Review focus.** For each input class or failure mode the spec implies, is there a task whose acceptance lines cover it?
   The five uncovered ones most likely to bite a person go in the Review Focus section, and each line there gets its acceptance line added to the owning task.
   An empty section means you checked and found none, not that you skipped the check.
7. **Checks proven both ways.** For every check the plan mandates, is there a step that shows it failing without its property and passing with it?
   Add the missing run; a check without one is a placeholder.
8. **Dictated text.** Check every block of dictated text against the repository's recorded decisions, the gates and rules in its agent instructions, and the findings recorded earlier in this design and plan.
   The implementer places it as written, so a contradiction the plan carries ships.
   For protocol text, read the text in each state of its States block, with the sentences around the place it goes, and check that it gives the outcome named there and contradicts none of them.
```

In "Execution handoff", after the sentence that begins "Otherwise, ask them to review the plan and choose", add:

```markdown
Recommend `build:execute` when the plan has about five tasks or fewer, so that the run fits one context, and no owner gate the agent performs.
Recommend `build:delegate` otherwise.
In both messages below, `<N>` counts the lines of the `## Plan` section.
```

The first message template (no execution method supplied) becomes:

```text
Plan complete and committed as docs/plans/<filename>.md: <N> lines over
<M> tasks; the longest is Task <K> at <L> lines, because <reason>.
Please review it. Which execution approach would you prefer?

- Delegate (build:delegate): a fresh subagent implements each task and a
  fresh reviewer gives a verdict on every acceptance line before the next
  one starts, then a whole-branch review at the end. Most thorough; costs
  a fresh context per task and per review. The default.
- Inline (build:execute): I implement every task myself in this session,
  then one fresh reviewer on the most capable model checks the whole
  branch. Cheapest and fastest; my own tests are the only check until
  that review. Needs a session model of the mid tier or above.

For this plan I recommend [one of the two], because [one sentence from the
plan: how many tasks it has, whether it has an owner gate the agent
performs, what a shipped mistake would cost]. You will not be asked again
until the branch is finished, except at the owner gates you do not
pre-approve.
[Only when the plan has an owner gate the agent performs:]
Inline, the code such a gate runs gets no independent review before the
gate, and a pre-approved gate passes on its Expected line alone.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does the plan capture what you want, and which approach should we use?
```

The second message template (an execution method already supplied) becomes:

```text
Plan complete and committed as docs/plans/<filename>.md: <N> lines over
<M> tasks; the longest is Task <K> at <L> lines, because <reason>.
Please review it.
[Only when the plan has an owner gate the agent performs and the method
is build:execute:]
Inline, the code such a gate runs gets no independent review before the
gate, and a pre-approved gate passes on its Expected line alone.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does it capture what you want?
```

In "With the Lyngon documents", the sentence that begins "Self-review item 6" becomes:

```markdown
Self-review item 8 checks dictated ADR text, `CLAUDE.md` lines and `CONCEPTS.md` entries against the existing ADRs and the gates and rules in `CLAUDE.md`.
```

**Commit:** `feat(build): write plans of decisions and facts, without steps or code`

### Task 4 `task-labels`: The executors name a task by its label

**Files:**

- Modify: `plugins/build/skills/delegate/SKILL.md`
- Modify: `plugins/build/skills/delegate/references/owner-gates.md`
- Modify: `plugins/build/skills/delegate/references/implementer-prompt.md`
- Modify: `plugins/build/skills/delegate/references/task-reviewer-prompt.md`
- Modify: `plugins/build/skills/delegate/references/re-review-prompt.md`
- Modify: `plugins/build/skills/delegate/references/evidence-reviewer-prompt.md`
- Modify: `plugins/build/skills/execute/SKILL.md`

**Interfaces:**

- Consumes: `task-brief --label` and the brief names of Task 1 `brief-slugs`; the `label:` line and the completion line of Task 2 `label-scripts`.
- Produces: `<label>` at the start of every ledger line format of both executors and of the owner gate protocol; `[LABEL]` in the four templates.

**Intent:** Both executors and the owner gate protocol write `Task <N>` or `Task N` wherever they name a task: in ledger line formats, in pause lines, in the argument of `execution-status write`, in the subject of a pause commit, in the gate message and in dispatch descriptions.
Each of those becomes the task's label, written `<label>` in the two skills and the protocol and `[LABEL]` in the four templates.
Each file name spelled `task-N-...` becomes a name derived from the brief path that `task-brief` printed.
Nothing else in the owner gate protocol changes.
The mandated check counts the old spellings in the seven files; it does not count the examples that use real numbers (`Task 6 pre-gate: ...`), which the acceptance lines cover.

**Acceptance:**

- Every example ledger line and every example task heading in the example workflows of `delegate/SKILL.md` and `execute/SKILL.md` names its task by number and slug, and the brief and report names there carry the slug.
- In every ledger line format, the words `minor (deferred)`, `parked`, `Ruling:`, `complete`, `fix round`, `evidence review`, `pre-gate` and `post-gate` keep their place after the label, so that `build:finish` and the resume checks find them as before.
- No shell command in the seven files holds a label with a backtick in it.
- `UPSTREAM.md` of `delegate` and of `execute` list the patch.

**States:**

- A plan whose headings carry slugs, a fresh run under `build:delegate`: the brief is `task-3-rate-limiter-brief.md`, the report is named after it, and every ledger line for the task starts `Task 3 rate-limiter`.
- The same plan under `build:execute`: `task-start` prints the label, the executor starts its own lines with it, and `task-done` writes the completion line under it.
- A plan whose headings carry no slug: the label is the word `Task` and the number, and every line and file name is what it was before this change.
- A task with an owner gate: `Task 6 state-bucket pre-gate: complete` and `Task 6 state-bucket post-gate: dispatched` are never read as `Task 6 state-bucket: complete`; the pause line, the argument of `execution-status write`, the pause commit's subject and the gate message carry the label bare.
- A run resumed in another checkout from the plan's Execution status: the ledger is restored verbatim, and its labels match the plan's headings.
- A lost workspace, reconciled from `git log`: the recovered completion lines are written under the label the plan's heading gives.
- A heading that gained, lost or changed its slug in the middle of a run: the old lines no longer match a heading, so they are not read as progress until `git log` shows the commits they name; then the task counts as done and a `State:` line says so.
- An unforeseen gate in a task the plan did not gate: its lines start with the label, and the start-step line names the step by number and slug when it has one.
- A label in a shell command (`execution-status write`, `git commit -m`, an append to the ledger): no backtick, so nothing is substituted.
- A dispatch description: `[LABEL]`, filled with the label.

**Dictated text:**

In `plugins/build/skills/delegate/SKILL.md`, section "Workspace and ledger", after the bullet that begins "Create the ledger with its identity", add this bullet:

```markdown
- Name a task by its label wherever you write about it: the word `Task`, its number and, when the plan's heading for it has a slug, the slug, as in `Task 3 rate-limiter`.
  `scripts/task-brief PLAN_FILE N --label` prints it.
  In the ledger, in a shell argument, in a commit message and in a file name the slug is bare; in Markdown it is in backticks, as the heading has it.
  `<label>` stands for it in every ledger line format below and in the owner gate protocol, and a task's brief and report carry the slug in their file names.
  The number identifies the task, and the slug is there to catch a wrong number: when a ledger line's number and slug do not belong to one heading of the plan, do not read the line as progress until you have checked `git log` for the commits it names.
  When they are there, the task is done, and you ledger `State: "<the line>" is <label>`; when they are not, it is not done.
```

In "1. Dispatch the implementer", the first sentence of the bullet "**Task brief.**" becomes:

```markdown
- **Task brief.** Before dispatching an implementer, run this skill's `scripts/task-brief PLAN_FILE N`; it extracts the task's full text, followed by the plan's Global Constraints section, to a brief in the workspace named after the task's number and slug (`task-3-rate-limiter-brief.md`) and prints the path.
```

and the first sentence of the bullet "**Report file.**" becomes:

```markdown
- **Report file.** Name the implementer's report file after the brief, with `-report.md` in place of `-brief.md` (brief `task-3-rate-limiter-brief.md`, report `task-3-rate-limiter-report.md`, same workspace), and put it in the dispatch prompt.
```

In `plugins/build/skills/delegate/references/owner-gates.md`, section "Ledger lines", after the sentence that begins "Every `<time>` in a line", add:

```markdown
A line that names a task names it by its label: the word `Task`, its number and, when the plan's heading for it has a slug, the slug, bare (`task-brief PLAN_FILE N --label` prints it).
`<label>` stands for it throughout this file, also in a pause line, in the argument of `execution-status write`, in the subject of a pause commit and in the gate message.
Where a line, a gate message or a dispatch names a step that has a slug, it gives the step's number and slug, as in `Step 3 save-plan`.
```

The fenced block of example lines in that section becomes:

```text
Task 6 state-bucket pre-gate: complete (no commits; pins bootstrap.tfplan sha256:<64 hex digits>)
Gate apply-state-bucket: waiting for owner
Gate apply-state-bucket: owner 2026-09-27T14:51:55+0800: "Go ahead and apply!"
Gate apply-state-bucket: pre-approved (plan index); Expected lines matched
Gate apply-state-bucket: pre-approval void (Step 3 save-plan expected 6 to add, got 7 to add); asking
Task 6 state-bucket post-gate: dispatched
Gate apply-state-bucket: approval void (pin check: bootstrap.tfplan changed)
Pause 2026-09-27T14:11:02+0800: resume at Task 6 state-bucket pre-gate; removed backend_override.tf, bootstrap.tfplan
Resume 2026-09-27T14:39:40+0800: recreated the ledger from the plan's Execution status
Task 6 state-bucket: evidence review clean
Task 6 state-bucket: complete (commits 6033d2e..a1b2c3d, evidence review clean)
Reconcile 2026-09-27T14:39:41+0800: 3f2e1d0..HEAD; Task 7 smoke-test complete, recovered from b4c5d6e
Task 7 smoke-test: complete (recovered from git log: b4c5d6e)
```

and the sentence after that block becomes:

```markdown
`Task 6 state-bucket pre-gate:` never matches the resume check for `Task 6 state-bucket: complete`, so a finished pre-gate part never reads as a finished task.
```

In each of the four templates (`implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`, `evidence-reviewer-prompt.md`), section "Placeholders", after the `[MODEL]` item, add:

```markdown
- `[LABEL]`: required, the task's label as `scripts/task-brief PLAN_FILE N --label` prints it (`Task 3 rate-limiter`).
```

In `implementer-prompt.md`, the `[REPORT_FILE]` item, with its second line, becomes:

```markdown
- `[REPORT_FILE]`: required, named after the brief with `-report.md` in place of `-brief.md`, in the same workspace; one per task, and a prior attempt's file is kept and appended to.
  A gated task has two reports, one per part, each named after its brief in the same way.
```

In `plugins/build/skills/execute/SKILL.md`, section "Workspace and ledger", after the bullet that begins "Create the ledger with its identity", add this bullet:

```markdown
- Name a task by its label wherever you write about it: the word `Task`, its number and, when the plan's heading for it has a slug, the slug, as in `Task 3 rate-limiter`.
  `scripts/task-start` prints it, and `scripts/task-done` writes the completion line under it.
  In the ledger, in a shell argument, in a commit message and in a file name the slug is bare; in Markdown it is in backticks, as the heading has it.
  `<label>` stands for it in every ledger line format below and in the owner gate protocol.
  The number identifies the task, and the slug is there to catch a wrong number: when a ledger line's number and slug do not belong to one heading of the plan, do not read the line as progress until you have checked `git log` for the commits it names.
  When they are there, the task is done, and you ledger `State: "<the line>" is <label>`; when they are not, it is not done.
```

In "1. Take the task", the sentence that begins "It prints the brief path" becomes:

```markdown
  It prints the brief path, BASE (the commit the task's range is cut from) and the task's label in one call; the brief holds the task's text followed by the plan's Global Constraints, and the label starts every ledger line you write for the task.
```

**Commit:** `feat(build): name a task by its label in the ledger, the briefs and the dispatches`

- [ ] **Step 1 `check-fails`: Count the places that name a task by its number alone**

Run: `cat plugins/build/skills/delegate/SKILL.md plugins/build/skills/delegate/references/owner-gates.md plugins/build/skills/delegate/references/implementer-prompt.md plugins/build/skills/delegate/references/task-reviewer-prompt.md plugins/build/skills/delegate/references/re-review-prompt.md plugins/build/skills/delegate/references/evidence-reviewer-prompt.md plugins/build/skills/execute/SKILL.md | grep -cE 'Task (<N>|N\b)|task-N-|task-<N>'`
Expected: `37`

- [ ] **Step 2 `work`: Name every task by its label**

Place the dictated text, then make the replacements the Intent describes until the acceptance lines hold.

- [ ] **Step 3 `check-passes`: Show that none is left**

Run: `cat plugins/build/skills/delegate/SKILL.md plugins/build/skills/delegate/references/owner-gates.md plugins/build/skills/delegate/references/implementer-prompt.md plugins/build/skills/delegate/references/task-reviewer-prompt.md plugins/build/skills/delegate/references/re-review-prompt.md plugins/build/skills/delegate/references/evidence-reviewer-prompt.md plugins/build/skills/execute/SKILL.md | grep -cE 'Task (<N>|N\b)|task-N-|task-<N>'`
Expected: `0`

### Task 5 `implementer`: The implementer of a plan task writes the tests

**Files:**

- Modify: `plugins/build/skills/delegate/SKILL.md`
- Modify: `plugins/build/skills/delegate/references/implementer-prompt.md`

**Interfaces:**

- Consumes: the task blocks of Task 3 `plan-skill`.
- Produces: three items in the implementer's report, read by Task 6 `task-reviewer`: `**Acceptance**`, `**Task test command**` and `**States**`; a BLOCKED report that names a state and a sentence; a `State:` ledger line for a ruling that rewords dictated text.

**Intent:** The Design's "The delegate skill and its templates", the implementer's half.
The controller picks a mid-tier implementer for every plan task, and the implementer template tells it to turn acceptance lines into failing tests, to place dictated text as written and to stop when that text breaks a state.
The lines inside the template's fenced block are indented four spaces; the dictated template text below shows that indentation.

**Acceptance:**

- "Model selection" no longer says that most implementation tasks are mechanical, nor that complete code in the plan text means the cheapest tier.
- The paragraphs "Review tasks", "Evidence reviews", "Fix-loop escalation" and "Always specify the model explicitly" of "Model selection" are unchanged.
- The numbered list under "Your Job" in the template runs 1 to 7 without a gap, and its items on verifying, committing, self-review and reporting keep their text.
- `plugins/build/skills/delegate/UPSTREAM.md` lists the patches to the skill and to the implementer template.

**States:**

- A plan task without steps, first dispatch: a mid-tier implementer writes a failing test per acceptance line, then the code, and its report has the Acceptance item and the task test command.
- An acceptance line no test can run (descriptive prose, a configuration value): the report names the place in the diff that meets it and why no test could.
- A brief with steps (a mandated check, or a plan written before plans had none): worked in step order with every `Expected:` line compared; acceptance lines, when the brief has them, are still covered.
- The pre-gate and the post-gate brief of a task with an owner gate: the `[OWNER_GATE]` text still governs, the pre-gate part still commits nothing, and a part without acceptance lines reports "none" under Acceptance.
- A brief with a States block: the implementer reads the placed text in each state; on a conflict it reports BLOCKED and rewords nothing; the controller rules, ledgers the ruling and a `State:` line, and re-dispatches.
- A brief without an Acceptance block (an earlier plan, or a batch of same-shape edits the controller composed): the report says "none" under Acceptance and nothing else changes.
- A fix round, resumed or fresh: "After Review Findings" still governs; the fix report needs no new Acceptance item.
- Model choice at each dispatch: mid tier for a plan task's implementer and reviewer, cheapest for a batch or a single-file mechanical fix, one tier up in fix rounds 4 and 5, most capable for the final review.

**Dictated text:**

In `plugins/build/skills/delegate/SKILL.md`, section "Model selection", the three paragraphs that begin "**Mechanical implementation tasks**", "**Integration and judgment tasks**" and "**Architecture and design tasks:**" become:

```markdown
**Plan tasks:** use a mid-tier model for the implementer of every plan task.
The plan is written for a skilled developer: it gives the interfaces, the acceptance lines and the facts of the repository, and the implementer writes the tests and the code, which the cheapest tier does poorly from prose.

**Tasks that need broad judgment** (the task judges other work, or its Intent says it needs an understanding of the whole codebase): use the most capable available model.
The final whole-branch review is one of these; dispatch it on the most capable available model, not the session default.

**Mechanical work:** the cheapest tier keeps the batch of small same-shape edits and the single-file mechanical fix, where the dispatch lists every file with its change.
```

In the same section, the paragraph that begins "**Turn count beats token price.**" becomes:

```markdown
**Turn count beats token price.**
Wall-clock and context cost scale with how many turns a subagent takes, and the cheapest models routinely take two to three times the turns on multi-step work, costing more overall.
Use a mid-tier model as the floor for task reviewers and for the implementers of plan tasks.
The reviewer of a task with a States block reasons about states the diff does not show, as a re-review with a walk list does.
```

and the sentence "Task complexity signals for implementation tasks:" with its list becomes:

```markdown
Signals for an implementation dispatch:

- A plan task: mid-tier model.
- A batch of same-shape edits, or a single-file mechanical fix: cheap model.
- A task that judges other work or needs broad codebase understanding: most capable model.
```

In "Read the plan", the sentence that begins "One row for every task:" becomes:

```markdown
One row for every task: whether its own text agrees with itself, its acceptance lines against its Interfaces block, its dictated text against its States, the files it creates against the files it later touches.
```

In "1. Dispatch the implementer", the sentence that begins "Exact values (numbers, magic strings" becomes:

```markdown
  Exact values (numbers, magic strings, signatures, acceptance lines, dictated text) appear only in the brief.
```

In "2. Handle the report", after item 4 of the numbered list under "**BLOCKED:**", add this paragraph:

```markdown
A BLOCKED report that names a state and a sentence of dictated text is the fourth case, and the state wins.
Rule on the smallest rewording that gives the state its outcome, ledger the ruling, and ledger the new wording as a `State:` line too, because it supersedes the plan's text for every reviewer from then on.
Re-dispatch with the reworded sentence carried in the dispatch.
```

In `plugins/build/skills/delegate/references/implementer-prompt.md`, under "Your Job", items 1 and 2 of the numbered list are replaced by these three, and the items after them are renumbered:

```text
    1. Build what the brief's Intent and acceptance lines require. The
       choices they leave open are yours; the exact values, names and
       signatures they give are not
    2. For each acceptance line, write a failing test before the code,
       the way practice:tdd requires, wherever the repository has a test
       surface for it. Where it has none (descriptive prose, a
       configuration value), note the place in your diff that meets the
       line. A brief with steps is worked in step order, and every
       `Expected:` line is compared with the real output
    3. Place dictated text word for word, where the brief locates it
```

After the "Your Job" section and before "You Do Not Dispatch Subagents", add this section:

```text
    ## Dictated Text and States

    Text the brief dictates is a decision: place it exactly as written.
    When the brief has a States block, read the placed text in each
    state as an actor in that state would, together with the sentences
    around it, and check that it gives the outcome the block names. If
    the text and a state disagree, the state wins, and the wording is
    not yours to change: stop and report BLOCKED with the state, the
    sentence and the outcome it gives instead.
```

In "Report Format", after the item that begins "What you tested and test results", add:

```text
    - **Acceptance**: every acceptance line of the brief, in its order,
      each with the test that covers it (file and test name), or the
      place in the diff that meets it and why no test could; "none" when
      the brief has no acceptance lines
    - **Task test command**: the one command that runs this task's own
      test files and nothing else, when the task has tests
    - **States** (when the brief has a States block): each state with
      the outcome you read in the placed text
```

**Commit:** `feat(build): give plan tasks a mid-tier implementer who writes the tests`

### Task 6 `task-reviewer`: The task reviewer gives a verdict per acceptance line and state

**Files:**

- Modify: `plugins/build/skills/delegate/references/task-reviewer-prompt.md`
- Modify: `plugins/build/skills/delegate/SKILL.md`

**Interfaces:**

- Consumes: the report items `**Acceptance**`, `**Task test command**` and `**States**` of Task 5 `implementer`; the task blocks of Task 3 `plan-skill`.
- Produces: the verdict words `COVERED`, `MET` and `MISSING` per acceptance line and `HOLDS` and `BROKEN` per state, which Task 7 `rehearsal` looks for and Task 9 `final-reviewer` reuses.

**Intent:** The Design's "The delegate skill and its templates", the reviewer's half.
Spec compliance becomes a verdict per acceptance line, the reviewer runs the task's own tests once where it used to run none, and a task with a States block gets a verdict per state.
The re-review template and the evidence reviewer template do not change.

**Acceptance:**

- The template's "Tests" section keeps its last paragraph, the one that begins "Evidence you cannot see".
- The line "**The reviewer returns:**" at the end of the template file names the verdict per acceptance line and per state.
- The example workflow in `SKILL.md` shows a task review that returns a verdict per acceptance line, and the implementer there reports a covering test per line.
- `plugins/build/skills/delegate/UPSTREAM.md` lists the patches to the task reviewer template and to the skill.

**States:**

- A task without steps whose every line has a test: each line COVERED, the tests run once with the reported command, spec ✅.
- A line met in the diff where the repository has no test surface for it: MET, no finding.
- A line met only in the diff where a test could have covered it, or covered by a test that would pass with the line violated: MISSING, a Missing finding, and the fix loop starts.
- A choice the brief leaves open: not a finding, unless Part 2 calls the result a defect.
- A brief with a States block: HOLDS or BROKEN per state, read from the whole file; BROKEN is Important and enters the fix loop, where the state walk for a fix to protocol text applies as before.
- Dictated text reworded by a ruling: the `State:` line reaches the reviewer in "State Changes", and the difference is not a finding.
- A report that lacks the Acceptance item or the task test command, for a brief with acceptance lines and tests: the controller resumes the implementer before it dispatches the review.
- A brief without an Acceptance block (an earlier plan, a batch): compared with its text as a whole, as before; the reviewer says that no test command was reported.
- A task with an owner gate: the evidence reviewer takes the review, and this template is not used.
- A re-review after a fix round: its own template governs, unchanged.
- A reviewer that cannot run commands: it says so and names the command it would run.

**Dictated text:**

In `plugins/build/skills/delegate/references/task-reviewer-prompt.md`, section "Tests", the first two paragraphs (the second is the one about warnings) become:

```text
    The implementer's report names the test that covers each acceptance
    line and shows RED and GREEN output. Treat both as claims. Run the
    task's own test files once, with the task test command the report
    names, and compare the result with the report; never run the whole
    suite, a race detector or a repeated loop. Running that command is
    the one exception to the read-only rule above, and it must leave the
    working tree as it was. If the report names no command, or you
    cannot run commands in this environment, say so and name the command
    you would run. If heavy validation seems warranted, recommend it in
    your report instead of running it.

    Warnings or other noise in the test output are findings; test output
    should be pristine.
```

In "Part 1: Spec Compliance", after the list of Missing, Extra and Misunderstood, add:

```text
    When the brief has an Acceptance block, give a verdict on every
    acceptance line, in the brief's order:

    - COVERED: name the test, and say why it would fail if the line were
      violated. Read the test to judge this; a test that would still
      pass is not coverage.
    - MET: the line is met at a place in the diff that you name, and the
      repository has no test surface that could have covered it.
    - MISSING: no test covers the line and nothing in the diff meets it;
      or its only test would pass with the line violated; or it is met
      in the diff alone where a test could have covered it.

    Every MISSING line is a Missing finding. A choice the brief leaves
    open (a name, a structure, the design of a test) is the
    implementer's and is not a finding, unless Part 2 calls the result a
    defect. A brief without an Acceptance block is compared with its
    text as a whole.

    When the brief has a States block, read the dictated text in each
    state as an actor in that state would, follow it to its outcome, and
    give each state HOLDS or BROKEN. For this check, and only for it,
    read the whole of every file the dictated text sits in: a sentence
    the task left alone that now contradicts the dictated text breaks
    the state. A BROKEN state is an Important finding. Dictated text
    that differs from the brief's wording is a Misunderstood finding,
    unless a state change listed above supersedes that wording.
```

In "Output Format", under "### Spec Compliance", after the two existing items, add:

```text
    - Acceptance (when the brief has an Acceptance block): one line per
      acceptance line, COVERED by [test] | MET at [file:line] | MISSING
    - States (when the brief has a States block): one line per state,
      HOLDS | BROKEN, with the sentence that breaks it
    - Tests run: [the command and its result, or why none was run]
```

In `plugins/build/skills/delegate/SKILL.md`, section "2. Handle the report", after the paragraph that begins "**DONE:**", add:

```markdown
A report without its Acceptance item, or without the task test command when the task has tests, for a brief that has acceptance lines, is incomplete: resume the implementer for the missing part before you dispatch the review.
```

In "3. Review the task", the bullet that begins "Do not ask a reviewer to re-run tests" becomes:

```markdown
- The task reviewer runs the task's own test files once, with the command the report names; its template says so.
  Do not ask any reviewer for more (the whole suite, a race run, a repeat); a re-reviewer follows its own template, and the fix report carries its test evidence.
```

In "Common rationalizations", add this row after the row that begins `| "Close enough on spec compliance"`:

```markdown
| "The report shows RED and GREEN, the reviewer need not run anything" | The report is a claim. One run of the task's own test files is the check, and a line without a test that would fail is Missing. |
```

**Commit:** `feat(build): review a task by a verdict per acceptance line and state`

### Task 7 `rehearsal`: Rehearse a plan without steps end to end

**Files:**

- Create, scratch only: `tmp/rehearsal/` (a throwaway repository, a helper script, prompts and run outputs; `tmp/` is gitignored)

**Interfaces:**

- Consumes: Tasks 1 `brief-slugs`, 3 `plan-skill`, 4 `task-labels`, 5 `implementer` and 6 `task-reviewer`, loaded from this worktree's `plugins/build`, `plugins/practice` and `plugins/review`.
- Produces: an empty record commit whose body is the evidence, or one fix commit per defect and then the record commit.

**Intent:** No test runs skill text, so nested headless sessions run it: one writes a plan with `build:plan` from a small Design, the next executes that plan with `build:delegate`.
This task judges whether other sessions followed three skills, which takes an understanding of all of them.

The throwaway repository `tmp/rehearsal/repo` starts on `main` with a `.gitignore` holding `/tmp/`, an executable `scripts/check-version` and a design file, then switches to `feat/rehearsal`.
`scripts/check-version` prints `version ok: <v>` and exits 0 when the file `VERSION` holds what `bin/slug --version` prints, and prints `version mismatch` and exits 1 otherwise, also when either is missing.
The Design in `docs/plans/<today>-rehearsal.md` fixes three things:

- `bin/slug <title>` prints the title in lower case with every run of characters outside `a-z0-9` replaced by one hyphen and no hyphen at either end; an empty title exits 2 with `slug: empty title` on stderr; its tests are plain bash in `tests/slug.sh`.
- `VERSION` holds `0.1.0` and `bin/slug --version` prints it; `scripts/check-version` reads both, so the exact string is the behaviour.
- `RELEASING.md` holds the release procedure, read on a first release and on a re-run after a failed release: bump `VERSION`, run `scripts/check-version`, tag `v<version>`; a tag that exists is never moved, and the re-run stops there and reports it.

A nested session is started like this, from the throwaway repository, so that no installed copy of the plugins and no user setting loads:

```bash
env -i HOME="$HOME" PATH="$PATH" TERM=dumb claude -p "$(cat "$prompt")" \
  --model sonnet --setting-sources project --strict-mcp-config \
  --plugin-dir "$worktree/plugins/build" --plugin-dir "$worktree/plugins/practice" \
  --plugin-dir "$worktree/plugins/review" \
  --allowedTools "Bash Read Write Edit Glob Grep Skill Agent" \
  --output-format stream-json --verbose >"$out" </dev/null
```

The last line of the stream has type `result` and holds `.session_id` and `.result`; `--resume <session id>` answers a session that ended its turn with a question.
The stream, not the result alone, is needed: a reviewer's verdicts reach the controller as a subagent's result.
The prompts say that this is a rehearsal by the plugin's maintainers in a throwaway repository, name the skill to use, ask `build:plan` to stop at its handoff, answer the handoff with `build:delegate` in this checkout without a worktree, and tell `build:delegate` to stop after the final review instead of invoking `build:finish`.

If the environment refuses to start a nested session, report BLOCKED with the output.
If a nested run departs from the skills, find the sentence of skill text that let it, fix it in the file that owns it (one commit per defect, `fix(build): ...`, under the Global Constraints), and run the rehearsal again from an empty `tmp/rehearsal`.

**Acceptance:**

- The plan session appended a `## Plan` section to the design file and committed it on `feat/rehearsal`.
- In that plan, every task heading has a slug after its number, and the task for `bin/slug` has no `- [ ] **Step` line and no fenced block of test code or implementation.
- The task for `VERSION` has steps, each with a slug after its number, that run `scripts/check-version` twice, with `Expected:` `version mismatch` before the work and `version ok: 0.1.0` after it.
- The task for `RELEASING.md` has a `**States:**` block that names both paths and a fenced `**Dictated text:**` block.
- The plan session's final message reports the plan's lines, its number of tasks and its longest task.
- The briefs and reports in the nested workspace (`tmp/build/<plan>/`) carry each task's slug in their names, and every `complete` line of the nested ledger starts with the task's number and slug.
- Each task's report there has an Acceptance item that names a test or a place in the diff for every acceptance line.
- The stream of the delegate session holds a task review with a `COVERED`, `MET` or `MISSING` verdict for every acceptance line of the `bin/slug` task, and a `HOLDS` or `BROKEN` verdict for both states of the `RELEASING.md` task.
- The nested ledger has a completion line for every task, and the session stopped after the final review.
- In the throwaway repository, `bash tests/slug.sh` exits 0 and `scripts/check-version` prints `version ok: 0.1.0`.
- The record commit's body lists the `claude --version` output and the nested model, each session's id, every line above with its result, and the defects found with their fix commits, or "none".

**Commit:** `test(build): rehearse a plan without steps end to end` (empty, `git commit --allow-empty`, after any fix commits)

### Task 8 `execute-skill`: The inline executor writes the tests and the code

**Files:**

- Modify: `plugins/build/skills/execute/SKILL.md`

**Interfaces:**

- Consumes: the task blocks of Task 3 `plan-skill`; `<label>` as Task 4 `task-labels` defines it.
- Produces: the ledger line `<label>: walked <state>: <outcome>; ...`, one pair per state.

**Intent:** The Design's "The execute skill".
The inline executor is the implementer, so the skill tells it what the implementer template tells a subagent, and its completion contract speaks of acceptance lines.
`scripts/task-start` and `scripts/task-done` do not change.

**Acceptance:**

- `SKILL.md` nowhere says that the plan did the thinking, that execution is transcription, or that a plan is fully specified.
- In the process graph, every node an edge names is declared and every declared node has an edge.
- The example workflow shows a task worked as a failing test per acceptance line, not as numbered steps 1 to 5, and one task with a `walked` ledger line.
- "Why it is here" in `plugins/build/skills/execute/UPSTREAM.md` no longer says "a fully specified plan", and "Local patches" lists this change.

**States:**

- A task of code without steps: a failing test per acceptance line, then the code; the contract holds; `task-done` runs the task's own test files.
- A task whose lines no test can run: each line checked against the diff; `task-done` runs the repository's check for the files the task changed.
- A task with a States block: the executor walks the states after placing the text and ledgers the `walked` line; when the text and a state disagree it rewords the least it can and ledgers a ruling.
- A task with steps (a mandated check, an owner gate part, or a plan written before plans had none): step order, every `Expected:` line compared.
- A task with an owner gate: the owner gate protocol governs both parts, as before.
- A session resumed after compaction in the middle of a task: the ledger has no completion line, so the task is taken again from its brief.
- The final review and its fix pass: unchanged.

**Dictated text:**

In `plugins/build/skills/execute/SKILL.md`, the paragraph that begins "**Core principle.**" becomes:

```markdown
**Core principle.** The plan carries the decisions; the tests and the code are yours.
Build exactly what its acceptance lines, interfaces and dictated text say, prove each acceptance line with a test you watched fail and then pass, and leave a record that survives your own forgetting.
```

In "When to use", the paragraph that begins "A fully specified plan" becomes:

```markdown
The plan is written for a skilled developer, so inline execution needs a session model of the mid tier or above; below it, the plan's assumption about its implementer does not hold.
The one place the most capable model earns its cost is the final review, which this skill dispatches separately.
Tell the user so when they choose inline.
```

In the `digraph process` block, three nodes are renamed, in their declaration and in every edge: the node that begins "Work the steps in order" becomes `"Work the task: a failing test per acceptance line, then the code; a task with steps in step order"`, the node that begins "Step output matches" becomes `"Tests and Expected lines come out as the task says?"`, and the node that begins "Commit as the plan's commit steps say" becomes `"Commit with the subject the task gives"`.
The edge label `yes, last step` becomes `yes`.

In "1. Take the task", the sentence that begins "Read the brief for every task" becomes:

```markdown
  Read the brief for every task, including ones you remember from setup: what you remember is a summary, the brief has the exact values, signatures and acceptance lines.
```

The section "2. Work the steps" becomes, heading included:

```markdown
### 2. Work the task

A task without steps is yours to build, under `practice:tdd`, loaded at setup.
For each acceptance line, write the test first, run it and watch it fail, then write the code that makes it pass.
Watching it fail is part of the work, not a formality: a test that passes before the implementation exists is a finding about the test.
Where the repository has no test surface for a line (descriptive prose, a configuration value), check the line against your diff after the change.
The choices the task leaves open are yours; the exact values, names and signatures it gives are not.

Place dictated text word for word.
When the task has a States block, read the placed text in each state as an actor in that state would, with the sentences around it, and ledger the walk as `<label>: walked <state>: <outcome>; ...`, one pair per state.
When the text and a state disagree, the state wins: rule on the smallest rewording that gives the state its outcome, and ledger it as a ruling.

A task with steps is worked in step order: it holds an owner gate or a mandated check, or its plan was written before plans had tasks without steps.
Every step that runs a command has an `Expected:` line.
Run the command, read its output, and compare.

Whatever the task's kind, a test or a step that does not come out as the task says has one of two causes:

- **The code is wrong.** Call the Skill tool for `practice:debug`.
  Find the cause; never patch the symptom to make the output match.
- **The plan is wrong.** An acceptance line contradicts the spec, an interface from an earlier task does not match what this task consumes, a command cannot work.
  Rule on the smallest change that satisfies the spec, ledger it as `<label>: Ruling: <finding>; <what you decided and why>`, and continue.
  The ruling is carried, not remembered: later tasks that touch the same interface read it from the ledger.

Commit with the subject the task gives: one commit per task on the feature branch, Conventional Commits, one concern per commit.
A task that spans several commits is fine when the plan says so; BASE is what the review range is cut from, never `HEAD~1`.
Never commit on main.
```

In "3. The completion contract", the bulleted list becomes:

```markdown
- Every acceptance line has a test that ran in this task and that you saw fail before the implementation existed; or, where the repository has no test surface for the line, you checked it against the diff.
- In a task with steps, every `Expected:` line was compared against real output.
- A task with a States block has its `walked` line in the ledger.
- The final test run for the task passed: `task-done` is that run, and it writes the command and result into the ledger line.
- Every deviation from the brief has a `Ruling:` line in the ledger.
```

In "4. Complete the task", the first sentence becomes:

```markdown
Run this skill's `scripts/task-done PLAN_FILE N BASE -- <test command>` with the command that runs this task's own test files; a task whose acceptance lines no test can run takes the repository's check for the files it changed.
```

In "Common rationalizations", the rows that begin `| "The plan's code is right` and `| "I'll run the full suite at the end` become:

```markdown
| "The acceptance line is obvious, skip watching the test fail" | A test you never saw fail proves nothing. Run it before the code exists. |
| "I'll run the full suite at the end instead of per test" | Per-test runs are how you learn which change broke it. The end-of-task run is the contract, not a substitute. |
```

**Commit:** `feat(build): execute a plan whose tests and code are the executor's`

### Task 9 `final-reviewer`: The final reviewer checks acceptance lines and states across the branch

**Files:**

- Modify: `plugins/review/skills/request/references/code-reviewer.md`

**Interfaces:**

- Consumes: the task blocks of Task 3 `plan-skill`; the words `HOLDS` and `BROKEN` of Task 6 `task-reviewer`.
- Produces: the output section "Acceptance lines and states".

**Intent:** The Design's "The reviewer template of the review plugin".
The whole-branch reviewer already receives the plan in `{PLAN_OR_REQUIREMENTS}`; it now checks every task's acceptance lines and states on the branch as a whole, because the holes of the owner gates work sat between tasks and inline execution has no reviewer per task.
No placeholder is added, so the placeholder list in `plugins/review/skills/request/SKILL.md` stays true and that file does not change.

**Acceptance:**

- The line "**The reviewer returns:**" in the template file lists "Acceptance lines and states" among the sections.
- `plugins/review/skills/request/UPSTREAM.md` lists the patch.

**States:**

- A whole-branch review after `build:delegate` or `build:execute`, on a plan with Acceptance blocks: every line checked on the branch at its head, and the output has the new section.
- The same review on a plan with a States block: one line per state, HOLDS or BROKEN, and a BROKEN state is at least Important.
- A review of a bounded change, whose requirements are text and not a plan: the new paragraph does nothing and the output leaves the section out.
- A review of a plan written before this change, without Acceptance blocks: as the bounded change.
- A review whose Review Focus is empty or absent: that section is left out, as before.

**Dictated text:**

In `plugins/review/skills/request/references/code-reviewer.md`, section "Requirements or plan", after the `{PLAN_OR_REQUIREMENTS}` line, add:

```text
    When this is a plan whose tasks have Acceptance blocks, check every
    acceptance line of every task against the branch as it stands at
    {HEAD_SHA}: a later task may have broken what an earlier one built,
    and inline execution had no reviewer per task. Report each line that
    does not hold, or that no test covers where one could, as an issue
    that names the task and the line. When a task has a States block,
    read the text it dictated in each state, in the files as they stand
    now, and report every state as HOLDS or BROKEN; a BROKEN state is at
    least Important.
```

In "Review focus", the sentence that begins "These are the input classes" becomes:

```text
    These are the input classes and failure modes that no task's
    acceptance lines cover. Check each of these deliberately and report
    on each one, even when you find nothing.
```

In "Output format", after the "### Strengths" block, add:

```text
    ### Acceptance lines and states
    [For a plan with Acceptance blocks: "all N lines hold", or each line
    that does not, by task; then one line per state, HOLDS or BROKEN.
    Leave this section out otherwise.]
```

**Commit:** `feat(review): check acceptance lines and states across the branch`

### Task 10 `approach-check`: A design fixes the values the plan copies

**Files:**

- Modify: `plugins/discover/skills/approach/SKILL.md`

**Interfaces:**

- Consumes: nothing.
- Produces: nothing.

**Intent:** A plan now copies values and edge behaviours from the design and decides none, so a design that leaves one open hands the decision to whoever writes the plan.
`discover:approach` checks for that in the self-review of its design file.

**Acceptance:**

- `plugins/discover/skills/approach/UPSTREAM.md` lists the patch.

**Dictated text:**

In `plugins/discover/skills/approach/SKILL.md`, "Architectural path", step 7, after the bullet that begins "Ambiguity:", add this bullet at the same indentation:

```markdown
   - Fixed values: every value an implementer must use exactly (a name, a format, a limit, a message) is stated, and every edge behaviour is named with its outcome.
     The plan copies them and decides none, so one that is missing here is decided by whoever writes the plan.
```

**Commit:** `feat(discover): check that a design fixes its values and edge behaviours`

### Task 11 `workflow`: The workflow says what a plan holds

**Files:**

- Modify: `shared/WORKFLOW.md`

**Interfaces:**

- Consumes: the recommendation rule of Task 3 `plan-skill`.
- Produces: nothing.

**Intent:** `shared/WORKFLOW.md` is symlinked into `plugins/build/skills/plan/` and `plugins/discover/skills/approach/`, so this commit is a visible change to both plugins and bumps both.

**Acceptance:**

- "Who decides what" and the other flows of `shared/WORKFLOW.md` are unchanged.
- The `CHANGELOG.md` of `build` and of `discover` each have an entry for this commit.

**Dictated text:**

In `shared/WORKFLOW.md`, section "Architectural change", steps 2 and 4 of the numbered list become:

```markdown
2. `/build:plan` appends the plan to that file (the tasks in order, with their interfaces, acceptance lines, dictated text, owner gates and mandated checks; the implementer writes the tests and the code) and commits it on the feature branch.
```

```markdown
4. `/build:delegate` (a fresh implementer per task, and a reviewer after each task who gives a verdict on every acceptance line; the default) or `/build:execute` (inline, one review at the end; for a plan of about five tasks or fewer with no owner gate the agent performs) builds it, one commit per task, without asking, and stops only at owner gates.
```

**Commit:** `feat(build,discover): say what a plan holds in the workflow`

### Task 12 `seed-prompt`: Remove the landed seed prompt

**Files:**

- Delete: `docs/seed-prompts/lighter-plans.md`
- Modify: `docs/TODO.md`

**Interfaces:**

- Consumes: nothing.
- Produces: nothing.

**Intent:** The work the seed prompt started has landed on this branch, so the prompt and its queue entry go, as the seed prompt itself asks.

**Acceptance:**

- `docs/seed-prompts/lighter-plans.md` does not exist.
- `docs/TODO.md` has no "Lighter plans" entry under "Queued", and its other entries are unchanged.
- No file outside `docs/plans/` mentions `seed-prompts/lighter-plans.md`.

**Commit:** `docs(todo): remove the item on lighter plans`
