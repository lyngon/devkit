---
name: plan
description: >-
  Write an implementation plan from a settled design: the tasks in order, each with
  its interfaces, its acceptance lines and any dictated text, appended as the Plan
  section of the design file under docs/plans/, and hand it to build:delegate or
  build:execute. Use when a design or spec exists and no code has been touched: "the
  design is settled, write the implementation plan", "write the plan", "plan the
  implementation". Not for design questions (that is discover:approach) and not for
  fixes too small to need a plan.
---

# Plan

## Overview

Write a plan for a skilled developer who knows almost nothing about this repository's toolset or problem domain.
The implementer writes the tests and the code.
The plan lays out the tasks in order and carries what such a developer cannot know or must not decide:

- Cannot know: the files and where they go, the interfaces neighbouring tasks rely on, the repository's commands, and the facts of its toolset and domain.
- Must not decide: the values the spec fixes, the behaviour (as acceptance lines), the wording of dictated text, owner gates and mandated checks.

Every line in a task is one of these, and a line that is neither is cut.
There is one standard for every plan: it names no model tier and reads the same for either executor.
DRY. YAGNI. One commit per task.

The flow this skill sits in, from `discover:approach` to `build:finish` and the user's two review gates, is in [WORKFLOW.md](WORKFLOW.md).

## Where the plan lives

One file per piece of work, `docs/plans/YYYY-MM-DD-<slug>.md`, committed on the feature branch.
`discover:approach` starts the file with a `## Design` section (goal, approach, components, data flow, error handling, testing, out of scope).
This skill appends a `## Plan` section to that file.
When no such file exists because the design came from somewhere else, create it with the same naming and a `## Design` section that points at the spec, then append the plan.

The plan is transient.
`build:finish` removes the file in a final commit when the branch is done: the work is then in the git history, and a decision worth keeping was recorded where decisions are kept, not in the plan.

## Scope check

If the design covers several independent subsystems, it should have been split during discovery.
If it was not, suggest separate plans, one per subsystem.
Each plan should produce working, testable software on its own.

## File structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for.
This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces.
  Each file has one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused.
  Prefer smaller, focused files over large ones that do too much.
- Files that change together live together.
  Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns.
  If the codebase uses large files, do not restructure on your own, but if a file you are modifying has grown unwieldy, including a split in the plan is reasonable.
- The repository's layout decides where files go.
  The paths in this skill's examples are illustrations, not a layout.

This structure informs the task decomposition.
Each task produces self-contained changes that make sense independently.

## Task right-sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate.
When drawing task boundaries, fold setup, configuration, scaffolding and documentation steps into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbour.
Each task ends with an independently testable deliverable.

## Plan section header

Every `## Plan` section starts with this header:

```markdown
## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` or `build:execute` to implement this plan task by task. A task has steps (checkbox `- [ ]` syntax) only where it holds an owner gate or a mandated check.

**Goal:** [One sentence describing what this builds]

**Architecture:** [Two or three sentences about the approach]

**Tech stack:** [Key technologies and libraries]

**Spec:** [The `## Design` section of this file, or the external spec it points at. The plan argues from the spec, so the spec travels with it; executors read both.]

### Owner Gates

[One row per owner gate in the plan (see Owner gates below), or the single line "None." when the plan has none:

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-state-bucket` | Task 6 `state-bucket` | agent | creates the state bucket; versions kept forever | no |

Pre-approved says "no" until the user pre-approves the gate at the handoff, and then holds their reply verbatim with its time; a gate that an instruction of the repository keeps from pre-approval says "not pre-approvable (<the instruction>)".]

### Global Constraints

[The spec's project-wide requirements: version floors, dependency limits, naming and copy rules, platform requirements. One line each, with exact values copied verbatim from the spec. A rule that repeats in every task (a version bump with its changelog entry, a hook run) goes here once and never into a task. Every task's requirements implicitly include this section.]

### Review Focus

[The five input classes or failure modes the spec implies but no task's acceptance lines cover that are most likely to bite a person using this software. One line each, naming the input or condition and the behaviour a reasonable person would expect, most likely first. The spec is a vision document: it says what the software must do, not everything it will meet, and its silence on an input is not permission for that input to break the program. Write the list here, once, with the spec in front of you. Then, for each line, add the acceptance line that pins it to the task that owns the code.]
```

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

## Owner gates

A task that exists to perform a hard-to-reverse action only the user may approve or perform (an apply, a deletion, a deploy, a production migration, a publish, a key rotation) carries an owner gate: a step where the executor stops until the user decides.

```markdown
- [ ] **Step 4: Owner gate `apply-state-bucket`**
  - Show: `bootstrap.plan.txt` (rendered `tofu show` of `bootstrap.tfplan`)
  - Acts on: `state/bootstrap.tfplan`
  - Ask: "Apply this saved plan to the Common account?"
  - Performed by: agent, `tofu -chdir=state apply -input=false bootstrap.tfplan`
  - Consequences: creates the state bucket with `prevent_destroy`; every state version is kept forever; removing it needs a plan change
  - On no: record the reason, treat it as a finding on the pre-gate steps, regenerate, ask again
```

- The marker carries the gate's ID, kebab-case and unique in the plan; the index, a pre-approval, the ledger and the record commit name the gate by it.
  A step title says "owner gate" only in a marker, spelled as above: the executor refuses a task with any other step title that says it, and a task that the index names without holding the marker with its ID.
- Each field is one line directly under the marker, indented two spaces. `Show`, `Ask`, `Performed by`, `Consequences` and `On no` are required; `Acts on` names what the approval pins when that differs from `Show`. `Show` and `Acts on` may list several files.
- `Performed by` is `agent, <exact commands>` or `owner, <exact commands or instructions>`. The agent may perform an action only when the approval pins its effect: a frozen artifact (a saved plan, a packed tarball, an image by digest) by its hash; a command whose text and pinned inputs fully determine the effect; or an action that depends on live state, when the post-gate steps re-run its dry run right before acting and compare it byte for byte, which needs a deterministic dry run. The user performs everything else, a console action included.
- `Consequences` says what a yes changes, which part of it cannot be undone, and how to recover if anything can.
- A task has at most one gate. A sequence of irreversible actions is a sequence of tasks, so each is verified before the next runs.
- The steps before the gate do only reversible work inside the worktree (scratch files, saved plans, dry runs) and read-only calls, and commit nothing; the step that produces what the gate shows has an `Expected:` line. The code the action needs is written, committed and reviewed in an earlier task.
- The steps after the gate check the pins, perform or verify the action, run the checks, and end with the record commit: empty (`git commit --allow-empty`) when nothing in the repository changed, with the evidence in its body, which starts with the line `Owner gate: <id>` (then the answer or the pre-approval, the pins, the commands in order with their results, the results of the checks).
- The task's Files block lists the pre-gate artifacts as `Temporary:`, so a paused run knows what to remove; otherwise the executor removes them once the evidence review is clean, not before, because the reviewer checks against them.
- An owner action appears nowhere but at a gate inside a task: never after the branch is finished, never at the pull request.
- Approving the plan pre-approves nothing. A gate can be pre-approved at the handoff only when the agent performs it, the step that produces its artifact has an exact `Expected:` line (such as `Plan: 6 to add, 0 to change, 0 to destroy.`), and no instruction of the repository requires the user's approval at run time.

The executors' protocol at a gate is in `build:delegate`'s `references/owner-gates.md`.

## Checks and commands

Every check the plan mandates (a script, a command with an expected output, a condition a task verifies before it proceeds) is proven both ways.
The plan's steps show each one failing when its property does not hold and passing when it does, with the expected output of both runs, the same discipline the tasks apply to code.
A check seen only one way may not test its property at all: under `set -o pipefail`, `cmd | grep -q 'lock held'` is false whenever `cmd` exits non-zero, so a check for a held lock fails exactly when the lock is held.

A mandated check is a command whose exact output the plan pins, and it puts steps into its task, so use one in two cases only.
The first is a string that a script reads or that other text links to (a heading used as an anchor, a ledger line format, a version number a validator checks), where the presence of the exact string is the behaviour.
The second is a behaviour whose false green would be expensive.
Everything else is an acceptance line, which the implementer covers with a test.

A command a person runs by hand (an owner step, a recovery step in a README) is POSIX sh, or runs through `bash -c '...'` explicitly.
Their shell may be zsh, where bash-only syntax such as `${PIPESTATUS[0]}` prints nothing.
When the conventions plugin is installed, `conventions:shell` holds the rules an implementer meets while writing scripts.

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

## Self-review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it.
This is a checklist you run yourself, not a subagent dispatch.

1. **Spec coverage.** Skim each section and requirement in the spec.
   Can you point to a task that implements it? List any gaps.
2. **Placeholder scan.** Search your plan for the patterns in "No placeholders" above.
   Fix them.
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
   Check, too, that every dictated block's fence is longer than any fence inside it; the executors refuse a plan in which a fence opens inside a fence of the same length.
9. **Owner gates.** Every task that performs an action an executor must stop for (an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree) has a gate, and no step before a gate performs such an action.
   Every gate has all its fields, and the index has exactly one row per gate, or "None." when there is none.
   Every gate the agent performs has an action its approval pins, and every dry run a post-gate step compares is deterministic.
   The step that produces a pre-approvable gate's artifact has an exact `Expected:` line, and every gate that an instruction of the repository keeps from pre-approval is marked, with the instruction named.

If you find issues, fix them inline.
No need to re-review; fix and move on.
If you find a spec requirement with no task, add the task.

## Execution handoff

After writing and self-reviewing the plan, commit the file on the feature branch.
If you are still on the main branch, create the branch first (`git switch -c <branch>`): nothing is committed on main without the user's explicit consent.
Then link the file for the user to read.

This is the first of the user's two review gates; the second is the pull request that `build:finish` opens.
Between the two the executor asks them nothing except at owner gates: it rules on conflicts, records its rulings in a ledger, and presents them in the pull request description.

If the user has already explicitly supplied an execution method, ask them to review the plan and confirm it captures what they want; wait for that review before implementation, then use the supplied method.
Otherwise, ask them to review the plan and choose an execution method before implementation.
Recommend `build:execute` when the plan has about five tasks or fewer, so that the run fits one context, and no owner gate the agent performs.
Recommend `build:delegate` otherwise.
In both messages below, `<N>` counts the lines of the `## Plan` section.

When no execution method has been supplied (leave out ", except at the owner gates you do not pre-approve" when the plan declares no owner gates):

```text
Plan complete and committed as docs/plans/<filename>.md: <N> lines over
<M> tasks; the longest is Task <K> `<slug>` at <L> lines, because
<reason>.
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

When an execution method has already been supplied:

```text
Plan complete and committed as docs/plans/<filename>.md: <N> lines over
<M> tasks; the longest is Task <K> `<slug>` at <L> lines, because
<reason>.
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

Write each pre-approval the user gives into the index's Pre-approved column: their reply, verbatim, with the time from `date +%Y-%m-%dT%H:%M:%S%z`.
Where a hook rejects a character of a verbatim answer, or a `|` would break a table, replace only that character with its plain form (`'`, `"`, `-`, `\|`) and keep the rest verbatim.
A reply that approves the plan without naming a gate pre-approves none, and a gate marked not pre-approvable stays so whatever the reply says.
Commit the index as `docs(plan): record pre-approved owner gates` before invoking the executor.

If delegation is chosen, call the Skill tool for `build:delegate`.
If inline execution is chosen, call the Skill tool for `build:execute`.

## With the Lyngon documents

A decision made while planning that is hard to reverse, surprising without context and the result of a real trade-off is recorded as an ADR in `docs/adr/`: call the Skill tool for `discover:domain-model`.
A term settled while planning goes into `CONCEPTS.md` the same way.
Self-review item 8 checks dictated ADR text, `CLAUDE.md` lines and `CONCEPTS.md` entries against the existing ADRs and the gates and rules in `CLAUDE.md`.
The plan itself is none of the four documents (`INTENT.md`, `CLAUDE.md`, `CONCEPTS.md`, the ADRs); it carries no purpose, working rule, term or decision that has to outlive the branch.
