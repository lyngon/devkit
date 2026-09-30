# Owner gates and resumable runs

## Design

### Goal

The build skills get one protocol for every point where an executor stops for the owner, whether the plan foresaw it or not.
It covers how a plan declares an owner gate, how the owner pre-approves one, how the executor stops, asks, pauses across sessions and resumes, how a task that changes a live system is reviewed, and how the evidence outlives the workspace.
The decisions are in [ADR 0018](../adr/0018-owner-gates-are-declared-in-the-plan-and-pre-approved-by-name.md), and the terms (review gate, owner gate, pre-approval) are in [CONCEPTS.md](../../CONCEPTS.md).
The evidence is three lyngon.com sessions on 2026-09-26 and 2026-09-27: pull request 1 (the owner ran delete scripts, the agent verified) and pull request 3 (the agent ran `tofu apply` on saved plans the owner approved), both of which improvised every part of this.

### Approach

#### The owner gate in a plan

An owner gate is a step inside a task, with a fixed marker that carries its ID:

```markdown
- [ ] **Step 4: Owner gate `apply-state-bucket`**
  - Show: `bootstrap.plan.txt` (rendered `tofu show` of `bootstrap.tfplan`)
  - Acts on: `infra/foundation/common/state/bootstrap.tfplan`
  - Ask: "Apply this saved plan to the Common account?"
  - Performed by: agent, `tofu -chdir=infra/foundation/common/state apply -input=false bootstrap.tfplan`
  - Consequences: creates `lyngon-tofu-state` in Common with `prevent_destroy`; every state version is kept forever; removing it needs the bucket admin and a plan change
  - On no: record the reason, treat it as a finding on the pre-gate steps, regenerate, ask again
```

- The ID is kebab-case and unique within the plan.
  The index, the pre-approval, the ledger, the record commit and the pull request description all name the gate by it.
- `Show`, `Ask`, `Performed by`, `Consequences` and `On no` are required.
  `Show` and `Acts on` take a list of files (pull request 3's Task 7 gated four saved plans at once).
- `Acts on` lists what the approval pins, when that differs from `Show`: the frozen artifact the action consumes, or the inputs of a command.
- `Performed by` is `agent, <exact commands>` or `owner, <exact commands or instructions>`.
- `Consequences` says what a yes changes, which part of it cannot be undone, and how to recover from it if anything can.
- A task has at most one gate.
  A sequence of irreversible actions is a sequence of tasks; pull request 1's owner task, with two owner runs and a verification after each, becomes two tasks.
- The steps before the gate are the task's pre-gate steps, and the steps after it are its post-gate steps.
  When no step comes before the gate (a console action), `Show` is the gate's own instructions.

`build:plan` writes an index as the first subsection of `## Plan`, before Global Constraints:

```markdown
### Owner Gates

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-state-bucket` | 6 | agent | creates the state bucket; versions kept forever | no |
```

Every gate step has exactly one row, and every row has a step.

#### What an approval pins

What the owner approves depends on the kind of action, and the kind decides who may perform it.

1. **A frozen artifact** (a saved plan, a packed tarball, a rendered manifest, an image by digest): the approval pins the artifact's sha256, checked immediately before acting.
   Plans prefer this form wherever the tool supports it.
2. **A command with pinned inputs**: no artifact exists, but the command text plus inputs pinned by hash (a script, migration files) or by immutable identifier (a commit SHA, a version, a digest) fully determine the effect, as in `git tag v1.2.0 3f2a9c1`.
   The approval pins the command text and those pins.
3. **An action that depends on live state**, whose dry run is only a forecast (pull request 1's delete scripts, a migration against a database others write to): the agent may perform it only when the post-gate steps re-run the dry run immediately before acting and its output matches the approved one byte for byte.
   Otherwise the owner performs it.
4. **Nothing to pin** (a console action, a vendor UI, a phone call): the owner performs it, and the plan commit pins the instructions.

The agent performs only actions whose effect the approval pins.
The owner performs everything else, and the post-gate steps verify the result.

A run-time approval pins one set of artifacts and lapses when the run pauses before the post-gate steps finish.
Resuming re-runs the pre-gate steps and asks again, even when the new artifact is identical.

#### Pre-approval

Approving the plan pre-approves nothing on its own.
The `build:plan` handoff lists the gates that can be pre-approved and asks which ones, by ID.
The owner's reply is written, verbatim with its time, into the index's Pre-approved column, and committed on the branch as `docs(plan): record pre-approved owner gates`.

A pre-approval holds only when all of these are true:

- The gate is performed by the agent; a gate the owner performs always stops.
- Every `Expected:` line of the pre-gate steps matched, and no ruling changed a step of the task.
  Otherwise the pre-approval is void for this run, and the gate asks, showing the mismatch.
- No repository instruction requires approval at run time.
  lyngon.com's `CLAUDE.md` ("the owner's explicit go-ahead for that specific plan") is one; `build:plan` marks such gates as not pre-approvable and names the instruction.
- For a kind 3 action, the post-gate re-check of the dry run passes.

A pre-approval survives a pause, because it is recorded on the branch and re-checked on every run.

#### Pre-gate steps

Pre-gate steps do only reversible work inside the worktree (scratch files, saved plans, dry runs) and read-only calls, and they commit nothing.
The code the action needs comes from earlier tasks, committed and reviewed there; both lyngon.com pull requests already worked this way.
So nothing is reviewed before the gate.
The owner reads an artifact made by reviewed code, and for a pre-approved gate the `Expected:` lines are the check.

An owner action appears nowhere but at a gate inside a task.
Pull request 1's plan put its owner task after the executor handed over, which is how its verification and record commits reached the pull request unreviewed.

#### The protocol at a gate

1. The pre-gate steps run: a dispatch in `build:delegate`, the executor itself in `build:execute`.
2. The executor compares the pre-gate `Expected:` lines, pins what the approval covers, and ledgers `Task N pre-gate: complete (...)` with the pins.
3. A pre-approved gate whose conditions hold is passed and ledgered.
   Any other gate gets the gate message and a `waiting for owner` line:

   ```text
   Owner gate apply-state-bucket (Task 6)
   Consequences: <verbatim from the plan>
   Artifact: <link>, sha256 1a2b3c4d5e6f
   <the Ask, verbatim>
   On no: <verbatim from the plan>
   Answer yes, no with what to change, or later.
   ```

   The artifact is quoted verbatim up to 40 lines; beyond that, the message quotes the `Expected:` lines and links the file.
   Only an explicit yes is a yes.
   At a gate the owner performs, the message gives the exact commands or instructions and asks for "done" once they have run, with the output when the owner has it.
   A no follows `On no`, and "later" pauses the run.
4. The answer is ledgered verbatim with its time.
5. The post-gate steps run in a fresh dispatch whose prompt carries the approval: the answer, the pins to check before acting, and the exact commands approved.
   They check the pins first (for a kind 3 action, they re-run the dry run and compare it), perform or verify the action, run the checks, and end with the record commit.
6. The evidence reviewer reviews the task (both executors), and the task completes as `Task N: complete (commits <base>..<head>, evidence review clean)`.

#### Stops the plan did not foresee

An implementer reporting BLOCKED on an ungated apply, a plan defect with no way forward, a check that could only be passed by weakening it: each of these becomes an owner gate with the ID `unplanned-<slug>`.
Its `Show` is the executor's statement, written to the workspace as `gate-<id>.md`: what it met, the options and what each costs, plus any artifact the implementer produced.
The current task splits where it stopped.
The steps already done are its pre-gate part, and the rest runs after the answer as a fresh post-gate dispatch.
It can never be pre-approved.
The owner's answer is also ledgered as a `State:` line, so every later reviewer judges against it.
A final-review finding that needs a live change gets such a gate in the fix wave.

#### Pause and resume

A run pauses on "later" at a gate, when the owner ends the session, or when the executor is about to end with a stop unanswered.
The executor then:

1. removes the task's pre-gate artifacts, so a stale one can never be acted on (the task's Files block lists them as temporary);
2. appends `Pause <time>: resume at Task N pre-gate; removed <files>` to the ledger;
3. writes `## Execution status` at the end of the plan: two header lines, `Resume at: Task N pre-gate (gate <id>)`, and the ledger verbatim in a fence;
4. commits it as `docs(plan): pause at gate <id>`, without pushing (the message gives the push command for a backup);
5. ends with a resume prompt to paste: the executor and the plan path.

On start, the executor's setup reads the section.
A missing ledger is recreated from it; a ledger that the section's copy extends is replaced by the copy; a ledger that extends the copy is kept.
Any other disagreement is an unforeseen stop.
The section stays until the next pause rewrites it or `build:finish` removes the plan.

A session can also end without a pause.
On resume, every gate whose post-gate part never completed re-runs its pre-gate steps, and its run-time approval has lapsed.
A post-gate dispatch that started but never reported may already have acted, so it becomes an unforeseen stop showing its report file, never a blind re-run.
An owner's "done" is different, because it records an action that has already happened.
A pause or a lost session after it resumes at the post-gate steps, which verify.

#### Ledger lines

```text
Task 6 pre-gate: complete (no commits; artifacts task-6-plan.txt sha256:1a2b3c4d5e6f)
Gate apply-state-bucket: waiting for owner
Gate apply-state-bucket: owner 2026-09-27T14:51:55+08:00: "Go ahead and apply!"
Gate apply-state-bucket: pre-approved (plan index); Expected lines matched
Gate apply-state-bucket: pre-approval void (Step 3 expected 6 to add, got 7 to add); asking
Task 6 post-gate: dispatched
Pause 2026-09-27T14:11+08:00: resume at Task 6 pre-gate; removed backend_override.tf, bootstrap.tfplan
Resume 2026-09-27T14:39+08:00: ledger recreated from Execution status
Task 6: complete (commits 6033d2e..a1b2c3d, evidence review clean)
```

`Task 6 pre-gate:` never matches the resume check for `Task 6: complete`.

#### Evidence

Every task that passes an owner gate ends with a record commit.
Its message body is the evidence: the gate ID, the owner's answer verbatim with its time (or the pre-approval), the pins, the commands run in order with their result lines, and the results of the checks.
When the repository did not change, the commit is empty (`git commit --allow-empty`).
Pull request 1 did this for its deletions.
The body holds summaries and identifiers, never a secret.

Every task therefore ends with at least one commit.
The completion line keeps its commit range, `review-package` works unchanged, and the build 0.2.0 allowance "a brief may declare that the task commits nothing" goes away.
`build:finish` adds an "Owner gates" section to the pull request description: each gate's ID, the answer or the pre-approval, and its record commit.

#### Reviews

The evidence reviewer is a new template next to the task reviewer.
Its inputs are both briefs, both reports, the artifacts and their pins, the gate's ledger lines, the review package of the task's commits (with the record commit), the `State:` lines, and read-only access to the live system.
Its baseline is the approved artifact.
It checks that the action matched the approval and nothing else ran, that the live state is what the task's Produces block says, that every check was shown both ways, and that the record commit is accurate.
`build:execute` dispatches it too, because its final review reads a diff and cannot see live state; without a subagent tool it becomes a ledgered self-review.

The final whole-branch review stays after the last task, gated or not, and sees every record commit in its package.
There is no separate review after an owner step.

#### ADR edits

The rule "an accepted ADR is never rewritten" becomes a test: an edit is allowed only when someone who acted on the old text would act the same way on the new one.
Aligning terminology with `CONCEPTS.md`, fixing a typo or a broken link, and adding a forward pointer pass; anything that widens, narrows or reverses the decision, its reasons or its consequences is a new ADR.
This is organization-wide, in `conventions:adr` and `shared/ADR-FORMAT.md`, and retires the devkit-only exception of 2026-09-29.
Under it, ADR 0016 gets "review gates" for "gates" and a pointer to ADR 0018; its ledger sentence stays, and ADR 0018 records the exception.

### Components

`plugins/build/skills/plan/SKILL.md`

- The gate step with its fields in Task structure, and the Owner Gates index in the plan header.
- The rules: an owner action only at a gate inside a task; pre-gate steps as above; the four kinds and who performs each; every task ends with at least one commit, and a gated task with its record commit.
- New self-review items: index and steps agree; no stop-list action outside a gate or before one; every required field present; every pre-approvable gate has an exact `Expected:` line on the step that produces its artifact; every kind 3 dry run is deterministic; gates that repository instructions keep from pre-approval are marked, with the instruction named.
- The handoff message lists the pre-approvable gates and asks which to pre-approve, by ID; the reply is recorded in the index and committed.

`plugins/build/skills/delegate/SKILL.md`

- The five stops become the owner gate protocol: planned gates, unforeseen stops, the gate message, the ledger lines.
- Pre-gate and post-gate dispatches, pinning, the approval block in the post-gate dispatch, the record commit.
- Pause and resume, with setup reading the Execution status.
- The evidence reviewer after a gated task; the final review unchanged in place; the Finish lists joined by the owner gates.

`plugins/build/skills/delegate/references/implementer-prompt.md`: the commit rule becomes "a task whose work lies outside the repository ends with a record commit, as the brief says"; a pre-gate implementer stops at the gate and never performs its action; a post-gate implementer checks the pins before anything else; a new `[APPROVAL]` placeholder.

`plugins/build/skills/delegate/references/evidence-reviewer-prompt.md`: new, as described under Reviews, in the shape of the task reviewer (verdicts, severities, the no-subagents contract), and read-only on the live system as on the checkout.

`plugins/build/skills/delegate/scripts/task-brief`

- A task ends at the next heading of the same or a higher level, so the last task no longer swallows `## Execution status`; this fixes the leak into pull request 3's Task 7 brief.
- `task-brief PLAN_FILE TASK [--part pre-gate|post-gate] [OUTFILE]`: for a gated task, the part is required and writes `task-N-pre-gate-brief.md` or `task-N-post-gate-brief.md`.
  The pre-gate brief holds the task header, Files, Interfaces, the pre-gate steps, the gate block and the fixed last line "Stop here: the controller takes the gate."; the post-gate brief holds the header, Files, Interfaces, the gate block and the post-gate steps.
  Both end with the Global Constraints.
- It refuses (exit 3, before any dispatch) a task with two gates, a gate missing a required field, a duplicate ID, an ID missing from the index, a part on an ungated task, and a gated task without a part.

`plugins/build/skills/delegate/scripts/pin` (new): `pin FILE...` prints one `sha256:<hex> <file>` line per file, with `sha256sum` or `shasum -a 256`, whichever exists; `pin --check sha256:<hex> FILE` exits non-zero on a mismatch.

`plugins/build/skills/delegate/scripts/execution-status` (new): `write PLAN_FILE RESUME_AT` replaces or appends the plan's `## Execution status` section from the ledger; `restore PLAN_FILE` applies the rules under Pause and resume and exits non-zero on a disagreement.

`plugins/build/skills/delegate/scripts/review-package` and `workspace`: unchanged; a test proves an empty record commit makes a valid package.

`plugins/build/skills/execute/SKILL.md` and its `task-start` and `task-done`: the same protocol inline (the executor runs both parts and asks itself), the evidence reviewer dispatched per gated task, pause and resume; the scripts pass the part through.

`plugins/build/skills/finish/SKILL.md`: Step 2 reads the Execution status copy when no ledger exists; the pull request description gains the "Owner gates" section.

`plugins/build/README.md`, each skill's `UPSTREAM.md` (the skills are vendored, so every change is a local patch), `CHANGELOG.md` and `plugin.json` (0.7.0).

`shared/WORKFLOW.md` (symlinked into `build` and `discover`): "Who decides what" names the review gates and owner gates, pre-approval and the protocol for every stop; Gate 1 includes the pre-approvals; the executor step names the owner gates; "What gets written where" adds the Execution status and the record commits.

`shared/ADR-FORMAT.md` and `plugins/conventions/skills/adr/SKILL.md`: the ADR edit test.

`plugins/conventions/skills/engineering/SKILL.md`: "Ask before any other effect outside the branch" gains that an owner gate pre-approved by ID counts as asking.

`docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`: "review gates" and the pointer to ADR 0018.

`devenv.nix`: the fixture tests of the build scripts join `enterTest`.

Versions: `build` 0.7.0; `conventions` and `discover` a minor bump each, in the commits that change them.

`docs/TODO.md` and `docs/seed-prompts/owner-gates.md`: the entry and the seed prompt go in the last commit.

### Data flow

A planned gate in `build:delegate`, from plan to pull request:

1. `build:plan` writes the gated task and the index, and the handoff asks for pre-approvals by ID; the reply goes into the index and is committed.
2. The executor's setup resolves the workspace, restores the ledger from an Execution status if there is one, and runs the pre-flight scan.
3. For the gated task it records BASE, extracts the pre-gate brief, dispatches, compares the `Expected:` lines, pins, and ledgers the pre-gate line.
4. It passes a pre-approved gate whose conditions hold, or asks with the gate message and ledgers the answer.
5. It extracts the post-gate brief and dispatches it fresh with the approval; the implementer checks the pins, acts or verifies, runs the checks and makes the record commit.
6. `review-package BASE HEAD` covers the task's commits; the evidence reviewer gets it with the evidence; the fix loop runs as for any task, and any new live action in it is an unforeseen gate.
7. After the last task, the final review covers the merge base to HEAD, record commits included.
8. `build:finish` writes the "Owner gates" section from the ledger's gate lines and the record commits, removes the plan (the index and any Execution status go with it), pushes and opens the pull request.

`build:execute` follows the same path with its own hands in steps 3 and 5 and a dispatched evidence reviewer in step 6.

### Error handling

When the pins do not match before acting, or a kind 3 dry run differs from the approved one, the post-gate part stops without acting and reports BLOCKED.
The approval or pre-approval is then void for this run, and the gate re-runs its pre-gate steps and asks.

A pre-gate `Expected:` line that does not match is handled as in any task, with a ruling or the fix loop, before the gate is reached.
A pre-approval no longer holds after that, and the gate asks.

When the action fails partway (one of four applies fails), the post-gate steps stop and act no further, as the plan's steps say, and the failure becomes an unforeseen gate showing the error.

A no follows the gate's `On no`.

A session that ends without a pause resumes as described above; a post-gate part that started but never reported is an unforeseen stop, never a blind re-run.
So is an Execution status that disagrees with the ledger.

`task-brief` refuses a malformed gate before any dispatch, and the executor rules on the plan defect, or stops when every path forward is a guess.

A repository instruction beats a pre-approval that contradicts it.
`build:plan` marks such gates, and an executor that meets a case the plan did not mark asks.

### Testing

- Fixture tests in bash, in the style of `plugins/repo/hooks/tests/hooks.sh`, run by `devenv test`:
  - `task-brief`: an ungated task unchanged; the last task stops before `## Execution status`; the pre-gate and post-gate briefs hold exactly their parts and the Global Constraints; each refusal exits 3; a gate marker inside a fence is ignored.
  - `pin`: the output format, a passing and a failing `--check`, and both hash tools (each hidden from PATH in turn).
  - `execution-status`: `write` appends, then rewrites in place, leaving the rest of the plan byte-identical; `restore` recreates, replaces and keeps as the rules say, and exits non-zero on a disagreement.
  - `review-package` accepts a range holding only an empty record commit and shows its message.
- The hooks check the skill text (markdownlint, prose-lint, typos), `validate-prerequisites` checks that `build` still needs only `documents`, and `validate-marketplace` checks versions and changelogs.
- A rehearsal before the pull request, since the protocol lives in skill text a script cannot run: a scratch repository in the scratchpad, a two-task plan whose tasks each have a gate on a harmless stand-in for a live system (a file outside the worktree), one pre-approved and one not, executed with `claude -p` and the local plugins.
  It passes when the pre-approved gate runs through, the other asks, a "later" produces the pause commit with the Execution status, and a new session resumes from it and finishes with both record commits.

### Out of scope

- A hold on the ledger against a second session in the same checkout (already deferred in `docs/TODO.md`).
- The roadmap for multi-piece work (its own seed prompt); the Execution status belongs to one plan, the roadmap spans several, so they stay separate files.
- Permission rules in a repository's `.claude/settings.json` that enforce gates mechanically; the gates rest on the plan, the skills and the repository's instructions.
- Pushing a paused branch; the pause message offers the command.
