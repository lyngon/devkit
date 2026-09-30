---
name: plan
description: >-
  Write an implementation plan of bite-sized, test-first tasks from a settled design,
  appended as the Plan section of the design file under docs/plans/, and hand it to
  build:delegate or build:execute. Use when a design or spec exists and no code has
  been touched: "the design is settled, write the implementation plan", "write the
  plan", "plan the implementation". Not for design questions (that is
  discover:approach) and not for fixes too small to need a plan.
---

# Plan

## Overview

Write a plan that an engineer with zero context for this codebase and questionable taste can execute.
Document everything they need: which files to touch for each task, the code, the tests, the docs they might need to check, how to test it.
Give them the whole plan as bite-sized tasks.
DRY. YAGNI. TDD. One commit per task.

Assume they are a skilled developer who knows almost nothing about this repository's toolset or problem domain, and who does not know good test design very well.

The flow this skill sits in, from `discover:approach` to `build:finish` and the user's two gates, is in [WORKFLOW.md](WORKFLOW.md).

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

## Bite-sized granularity

Each step is one action of two to five minutes:

- "Write the failing test" is a step.
- "Run it to make sure it fails" is a step.
- "Implement the minimal code to make the test pass" is a step.
- "Run the tests and make sure they pass" is a step.
- "Commit" is a step.

## Plan section header

Every `## Plan` section starts with this header:

```markdown
## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` (recommended) or `build:execute` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [Two or three sentences about the approach]

**Tech stack:** [Key technologies and libraries]

**Spec:** [The `## Design` section of this file, or the external spec it points at. The plan argues from the spec, so the spec travels with it; executors read both.]

### Owner Gates

[One row per owner gate in the plan (see Owner gates below), or the single line "None." when the plan has none:

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-state-bucket` | 6 | agent | creates the state bucket; versions kept forever | no |

Pre-approved says "no" until the user pre-approves the gate at the handoff, and then holds their reply verbatim with its time; a gate that an instruction of the repository keeps from pre-approval says "not pre-approvable (<the instruction>)".]

### Global Constraints

[The spec's project-wide requirements: version floors, dependency limits, naming and copy rules, platform requirements. One line each, with exact values copied verbatim from the spec. Every task's requirements implicitly include this section.]

### Review Focus

[The five input classes or failure modes the spec implies but no task's tests exercise that are most likely to bite a person using this software. One line each, naming the input or condition and the behaviour a reasonable person would expect, most likely first. The spec is a vision document: it says what the software must do, not everything it will meet, and its silence on an input is not permission for that input to break the program. Write the list here, once, with the spec in front of you. Then, for each line, add the test that pins it to the task that owns the code, in that task's own step style.]
```

## Task structure

````markdown
### Task N: [Component name]

**Files:**

- Create: `<package>/src/exact/path/to/file.py`
- Modify: `<package>/src/exact/path/to/existing.py:123-145`
- Test: `<package>/tests/exact/path/to/test.py`

**Interfaces:**

- Consumes: [what this task uses from earlier tasks, with exact signatures]
- Produces: [what later tasks rely on: exact function names, parameter and return types. A task's implementer sees only their own task; this block is how they learn the names and types neighbouring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pytest <package>/tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write the minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `pytest <package>/tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <package>/tests/path/test.py <package>/src/path/file.py
git commit -m "feat: add specific feature"
```
````

The paths and the test command above are illustrations; the repository's layout and its declared test command decide.
The commit step is one commit per task on the feature branch, in Conventional Commits form with one concern per commit.
A task may span several commits when the plan says so.
Every task ends with at least one commit; a task whose work lies outside the repository ends with a record commit, as a task with an owner gate does.
Never `git commit` on main.

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
- The steps after the gate check the pins, perform or verify the action, run the checks, and end with the record commit: empty (`git commit --allow-empty`) when nothing in the repository changed, with the evidence in its body (the gate ID, the answer or the pre-approval, the pins, the commands in order with their results, the results of the checks).
- The task's Files block lists the pre-gate artifacts as `Temporary:`, so a paused run knows what to remove.
- An owner action appears nowhere but at a gate inside a task: never after the branch is finished, never at the pull request.
- Approving the plan pre-approves nothing. A gate can be pre-approved at the handoff only when the agent performs it, the step that produces its artifact has an exact `Expected:` line (such as `Plan: 6 to add, 0 to change, 0 to destroy.`), and no instruction of the repository requires the user's approval at run time.

The executors' protocol at a gate is in `build:delegate`'s `references/owner-gates.md`.

## Checks and commands

Every check the plan mandates (a script, a command with an expected output, a condition a task verifies before it proceeds) is proven both ways.
The plan's steps show each one failing when its property does not hold and passing when it does, with the expected output of both runs, the same discipline the tasks apply to code.
A check seen only one way may not test its property at all: under `set -o pipefail`, `cmd | grep -q 'lock held'` is false whenever `cmd` exits non-zero, so a check for a held lock fails exactly when the lock is held.

A command a person runs by hand (an owner step, a recovery step in a README) is POSIX sh, or runs through `bash -c '...'` explicitly.
Their shell may be zsh, where bash-only syntax such as `${PIPESTATUS[0]}` prints nothing.
When the conventions plugin is installed, `conventions:shell` holds the rules an implementer meets while writing scripts.

## No placeholders

Every step must contain the actual content an engineer needs.
These are plan failures; never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling", "add validation", "handle edge cases"
- "Write tests for the above" without the actual test code
- "Similar to Task N" (repeat the code; the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code steps need code blocks)
- References to types, functions or methods not defined in any task
- A check without a control: a mandated script or command shown passing but never shown failing when its property does not hold
- A gate missing a required field, or an owner action anywhere but at a gate inside a task

## Self-review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it.
This is a checklist you run yourself, not a subagent dispatch.

1. **Spec coverage.** Skim each section and requirement in the spec.
   Can you point to a task that implements it? List any gaps.
2. **Placeholder scan.** Search your plan for the patterns in "No placeholders" above.
   Fix them.
3. **Type consistency.** Do the types, method signatures and property names you used in later tasks match what you defined in earlier tasks?
   A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.
4. **Review focus.** For each input class or failure mode the spec implies, is there a task whose tests exercise it?
   The five uncovered ones most likely to bite a person go in the Review Focus section, and each line there gets its test added to the owning task.
   An empty section means you checked and found none, not that you skipped the check.
5. **Checks proven both ways.** For every check the plan mandates, is there a step that shows it failing without its property and passing with it?
   Add the missing run; a check without one is a placeholder.
6. **Dictated prose.** Check every block of prose the plan dictates verbatim (a decision record, README steps, a working rule, a term's definition) against the repository's recorded decisions, the gates and rules in its agent instructions, and the findings recorded earlier in this design and plan.
   The implementer copies it as written, so a contradiction the plan carries ships.
7. **Owner gates.** Every task that performs a stop-list action (an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree) has a gate, and no step before a gate performs one.
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

When no execution method has been supplied:

```text
Plan complete and committed as docs/plans/<filename>.md. Please review it.
Which execution approach would you prefer?

- Delegate (build:delegate): a fresh subagent implements each task and a
  fresh reviewer checks it before the next one starts, then a whole-branch
  review at the end. Most thorough; costs a fresh context per task and per
  review. The default for more than a handful of tasks.
- Inline (build:execute): I implement every task myself in this session,
  then one fresh reviewer on the most capable model checks the whole
  branch. Cheapest and fastest; no independent review until the end. Runs
  well with a mid-tier session model, since the plan carries the design.

For this plan I recommend [one of the two], because [one sentence from the
plan: how much the tasks depend on each other's interfaces, how many there
are, what a shipped mistake would cost]. You will not be asked again until
the branch is finished, except at the owner gates you do not pre-approve.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does the plan capture what you want, and which approach should we use?
```

When an execution method has already been supplied:

```text
Plan complete and committed as docs/plans/<filename>.md. Please review it.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does it capture what you want?
```

Write each pre-approval the user gives into the index's Pre-approved column: their reply, verbatim, with the time from `date +%Y-%m-%dT%H:%M:%S%z`.
A reply that approves the plan without naming a gate pre-approves none, and a gate marked not pre-approvable stays so whatever the reply says.
Commit the index as `docs(plan): record pre-approved owner gates` before invoking the executor.

If delegation is chosen, call the Skill tool for `build:delegate`.
If inline execution is chosen, call the Skill tool for `build:execute`.

## With the Lyngon documents

A decision made while planning that is hard to reverse, surprising without context and the result of a real trade-off is recorded as an ADR in `docs/adr/`: call the Skill tool for `discover:domain-model`.
A term settled while planning goes into `CONCEPTS.md` the same way.
Self-review item 6 checks dictated ADR text, README steps, `CLAUDE.md` lines and `CONCEPTS.md` entries against the existing ADRs and the gates and rules in `CLAUDE.md`.
The plan itself is none of the four documents (`INTENT.md`, `CLAUDE.md`, `CONCEPTS.md`, the ADRs); it carries no purpose, working rule, term or decision that has to outlive the branch.
