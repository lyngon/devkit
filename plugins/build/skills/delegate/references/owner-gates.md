# Owner gates

The protocol both executors follow at an owner gate: a point where the executor stops until the owner decides.
`build:delegate` runs each part of a gated task as a dispatch; `build:execute` runs it itself.
Where they differ, this file says so.
The scripts named here are in `build:delegate`'s `scripts/` directory, `../scripts/` from this file; run them with `bash`.

## What a gate is

A plan declares an owner gate as a step inside the task that performs a hard-to-reverse action:

```markdown
- [ ] **Step 4: Owner gate `apply-state-bucket`**
  - Show: `bootstrap.plan.txt` (rendered `tofu show` of `bootstrap.tfplan`)
  - Acts on: `state/bootstrap.tfplan`
  - Ask: "Apply this saved plan to the Common account?"
  - Performed by: agent, `tofu -chdir=state apply -input=false bootstrap.tfplan`
  - Consequences: creates the state bucket with `prevent_destroy`; every state version is kept forever; removing it needs a plan change
  - On no: record the reason, treat it as a finding on the pre-gate steps, regenerate, ask again
```

The plan lists every gate in its `### Owner Gates` index, whose Pre-approved column holds the owner's pre-approval of a gate, verbatim and with its time, or "no".
The steps before the gate are the task's pre-gate part, and the steps after it are its post-gate part.
The pre-gate part does only reversible work inside the worktree and read-only calls, commits nothing, and writes what the owner must see.
The post-gate part performs exactly what was approved, or verifies what the owner performed, runs the checks, and ends with the record commit.

Every stop the plan did not foresee is an owner gate too; see [Unforeseen stops](#unforeseen-stops).

## Who performs the action

The executor performs an action only when the approval pins its effect:

- a frozen artifact (a saved plan, a packed tarball, a rendered manifest, an image by digest), pinned by its sha256;
- a command whose text and pinned inputs (files by sha256, immutable identifiers such as a commit SHA or a version) fully determine the effect;
- an action whose effect depends on live state, only when the post-gate part re-runs its dry run immediately before acting and the output matches the approved one byte for byte.

The owner performs everything else, including anything with nothing to pin (a console action, a vendor UI), and the post-gate part verifies the result.
A gate whose `Performed by` names the agent for an action the approval cannot pin is a plan defect: ask at the gate for the owner to perform it.

## The protocol

1. **Pre-gate part.** Record BASE, extract the brief with `task-brief PLAN_FILE N --part pre-gate` (`task-start PLAN_FILE N --part pre-gate` in `build:execute`), and run the part: in `build:delegate` a dispatch from the implementer template whose `[OWNER_GATE]` block holds the template's pre-gate text verbatim, with the report `task-N-pre-gate-report.md`, in `build:execute` your own steps.
   Nobody performs the gated action here.
   `task-brief` refuses a malformed gate, and a task the index names without its marker, before anything runs; rule on the plan defect, or stop when every path forward is a guess.
2. **Compare and pin.** Compare every `Expected:` line of the pre-gate steps with the real output; a mismatch is handled as in any task, with a ruling or the fix loop, before the gate.
   Pin what the approval covers with `pin <files>`: the files in `Acts on`, or in `Show` when the gate has no `Acts on`.
   Ledger `Task N pre-gate: complete (no commits; pins <file> sha256:<hex>, ...)` with every hash whole.
   A command with no file inputs is pinned by its text: ledger it in backticks in place of a file.
3. **Decide whether to ask.** A gate passes without asking only when its index row holds a pre-approval, `Performed by` names the agent for an action the approval pins, every pre-gate `Expected:` line matched, no ruling changed a step of the task, no pin check or dry-run re-check of this gate failed in this run, and no instruction of the repository requires the owner's approval of this action at run time.
   Then ledger `Gate <id>: pre-approved (plan index); Expected lines matched` and go to step 5.
   When a pre-approval exists but a condition fails, ledger `Gate <id>: pre-approval void (<the condition that failed>); asking`; an instruction of the repository that the plan did not mark wins over the pre-approval.
4. **Ask.** Send the gate message as a single `text` fence with more backticks than any fence in what it quotes, and add no formatting: the plan's text stays verbatim, backticks included, and nothing else gets backticks. Ledger `Gate <id>: waiting for owner`, and wait:

   ```text
   Owner gate <id> (Task N)
   Consequences: <verbatim from the plan>
   Artifact: <path>, sha256 <first 12 hex digits>
   <the Ask, verbatim>
   On no: <verbatim from the plan>
   Answer yes, no with what to change, or later.
   ```

   The message has one `Artifact:` line per pinned file.
   Below them, quote each artifact verbatim when it has at most 40 lines, and in place of a pinned file that is not text (a `.tfplan`) quote the gate's `Show` file; for a quote over 40 lines, give the pre-gate `Expected:` lines and the file's path instead.
   A gate pinned by a command's text shows `Command: <the command>` in place of the `Artifact:` line.
   At a gate the owner performs, a `Commands:` line followed by the exact commands or instructions takes the place of the `Artifact:` line and the quote, and the last line is `Answer done once they have run (with the output if you have it), no with what to change, or later.`
   Only an explicit yes at a gate the agent performs, or "done" at a gate the owner performs, passes the gate.
   Ledger every answer verbatim, a "later" too, with the time from `date +%Y-%m-%dT%H:%M:%S%z` run when the answer arrives, never a time taken before it: `Gate <id>: owner <time>: "<answer>"`.
   The answer travels on into the record commit's body and, through a pause, into the plan.
   Where a hook rejects a character of a verbatim answer, or a `|` would break a table, replace only that character with its plain form (`'`, `"`, `-`, `\|`) and keep the rest verbatim.
   When the pause commit is the one rejected, make the replacement in the ledger and run `execution-status write` again, so the plan's copy still matches the ledger.
   A no follows the gate's `On no`; "later" pauses the run (see [Pausing](#pausing)).
5. **Post-gate part.** Extract the brief with `task-brief PLAN_FILE N --part post-gate`, and ledger `Task N post-gate: dispatched` (`started` in `build:execute`).
   In `build:delegate`, dispatch a fresh implementer, never the pre-gate one resumed, because the gate may have spanned sessions; its report is `task-N-post-gate-report.md`, and the template's `[OWNER_GATE]` block carries the approval: the answer verbatim or the pre-approval, every pin, and the exact commands approved.
   Before anything else the part checks every pin with `pin --check sha256:<hex> <file>`, and for an action that depends on live state it re-runs the dry run and compares the output byte for byte with the approved one.
   A mismatch stops it without acting: ledger `Gate <id>: approval void (<the check that failed>)`; the approval or pre-approval is void for this run, and the gate goes back to step 1, where step 3 asks.
   An action that fails partway (one of several applies fails) stops the part, which acts no further, as the plan's steps say; the failure becomes an unforeseen gate that shows the error.
6. **Record commit.** The post-gate part ends with a record commit, empty (`git commit --allow-empty`) when the repository did not change.
   Its message body starts with the line `Owner gate: <id>`, followed by the evidence: the owner's answer verbatim with its time or the pre-approval, the pins, the commands run in order with their result lines, and the results of the checks.
   It holds summaries and identifiers, never a secret.
7. **Evidence review.** Generate `review-package PLAN_FILE BASE HEAD` and dispatch the reviewer in [evidence-reviewer-prompt.md](evidence-reviewer-prompt.md) with both briefs (for an unforeseen gate, the task's whole brief and `gate-<id>.md`, pinned or not, in their place), both reports, the pinned files, this gate's ledger lines verbatim (the pre-gate line with its pins, and every answer line or the pre-approval line), the `State:` lines and read-only access to the live system.
   In `build:delegate`, ledger its verdict when it arrives, before any fix round: `Task N: evidence review clean`, or `Task N: evidence review: <K> findings (<one-liners>)`; `build:execute` ledgers the lines its skill names.
   Screen its findings before any fix round: one whose fix needs another live action becomes an unforeseen gate, never a fix round.
   Every fix dispatch for the task after its post-gate part has acted, resumed or fresh, carries the post-gate `[OWNER_GATE]` block with its one-run sentence: "The approval covers one run of these commands. In a fix round, never run them again and take no other effect outside the repository: report BLOCKED instead."
8. **Complete.** In `build:delegate`, ledger `Task N: complete (commits <base7>..<head7>, evidence review clean)`, or `(commits <base7>..<head7>, <K> parked)` after a tripped breaker.
   In `build:execute`, `task-done` records the completion once the evidence review is clean.
   Then remove the task's temporary files (the `Temporary:` entries of its Files block); only a pause at the gate removes them earlier, because the evidence reviewer checks against them.

## Unforeseen stops

A stop the plan did not declare (an implementer reports BLOCKED on an ungated apply, the plan is broken beyond guessing, a check could only be passed by weakening it) runs the same protocol:

- Its ID is `unplanned-<slug>`.
- Its `Show` is `gate-<id>.md`, which you write in the workspace (what you met, the options and what each costs), plus any artifact the part produced; that artifact is its `Acts on`, which step 2 pins.
  With nothing to pin, the owner performs the action.
- The task splits where it stopped: the steps already done are its pre-gate part, keeping their report, and the rest runs after the answer as a post-gate part that carries the answer.
- `task-brief --part` refuses a task the plan did not gate, so for such a task the post-gate part gets the whole brief (`task-brief PLAN_FILE N`, or `task-start PLAN_FILE N` in `build:execute`) and the line `Steps 1 to K are done; start at Step K+1.` beside the `[OWNER_GATE]` block, where K is the last step done or, for an action the owner performed, the step that held that action.
  An unforeseen gate raised inside a task the plan gated (a partial apply, an evidence-review finding) gets that task's post-gate brief with the same line, not the whole brief.
  Commits the task made before it stopped stay; the post-gate part builds on them, and a resumed run never redoes them (see [Resuming](#resuming)).
- It can never be pre-approved.
- Ledger the answer as a gate line and as `State: owner answered <id>: "<answer>"`, so every later reviewer judges against it.

A final-review finding whose fix needs a live change gets such a gate in the fix wave.

## Pausing

A run pauses on "later" at a gate, when the owner ends the session, or when you are about to end with a gate unanswered.
When a task is at its gate (asked or answered, its post-gate part not started), in this order:

1. Remove the task's pre-gate artifacts, the files its Files block lists as temporary, so a stale one can never be acted on.
   After an owner's "done", remove nothing: the action has happened, and the run resumes at the post-gate part.
2. Append `Pause <time>: resume at Task N pre-gate; removed <files>` to the ledger, or `resume at Task N post-gate` after "done".
3. Run `execution-status write PLAN_FILE "Task N pre-gate (gate <id>)"`, or `execution-status write PLAN_FILE "Task N post-gate (gate <id>)"` after "done".
   It copies the ledger verbatim into an `## Execution status` section at the end of the plan, replacing an earlier one.
4. Commit the plan alone: `git commit -m "docs(plan): pause at gate <id>" -- PLAN_FILE`.
   Do not push; give the owner the push command in case they want a backup.
5. End with a prompt the owner can paste to resume: the executor's skill and the plan path.

When the owner ends the session with no task at its gate, remove nothing, append `Pause <time>: resume at Task N` (the first task without a completion line), run `execution-status write PLAN_FILE "Task N"`, commit the plan alone as in step 4 with the message `docs(plan): pause before Task N`, and end as step 5 says.

## Resuming

Follow these steps at every setup of a plan that declares owner gates or ends with an `## Execution status` section, before reading or creating the ledger, whether or not the run paused, and also when there is no ledger at all: a lost workspace looks like a fresh start, and only `git log` shows a gated task that has already acted.

1. When the plan ends with an `## Execution status` section, run `execution-status restore PLAN_FILE`, also when a ledger is present.
   It recreates a missing ledger from the copy, replaces a ledger that the copy extends, keeps a ledger that extends the copy, and exits 1 when they disagree, which is an unforeseen stop.
   Ledger `Resume <time>: <what it printed>` on a line of its own, where what it printed is the text after its `execution-status:` prefix, verbatim, such as `recreated the ledger from the plan's Execution status`; what step 2 finds goes on the lines step 2 names.
2. Reconcile the ledger with `git log`, which outlives the workspace.
   Read `git log --format='%h %s%n%b' <since>..HEAD`, where `<since>` is the merge base with the default branch.
   For each task the ledger does not already show complete:
   - A task without a gate whose commit steps all appear in the log is complete: ledger `Task N: complete (recovered from git log: <commits>)`.
   - A gated task whose record commit appears in the log (the commit whose body has the line `Owner gate: <id>`, found with `git log --grep='^Owner gate: <id>$'`) has acted: never re-run its post-gate part.
     Ledger the answer or pre-approval the record commit's body holds, as the gate's usual `Gate <id>` line, only when the ledger lacks one.
     When the ledger shows its evidence review or an evidence-review fix round in progress, resume that loop at its next round; otherwise resume the task at step 7, the evidence review, which then completes it.
     When BASE was lost with the workspace, take as BASE the parent of the task's first commit in the log, which is the record commit's parent when that is the task's only commit.

Resume at the first task that is not complete.
Then, for the task at a gate:

- A run-time approval lapses when the session that received it ends before the post-gate part starts, at a pause or not: re-run the pre-gate part and ask again, even when the new artifact is identical.
  An unforeseen gate is the exception: the commits its steps made stay, and you re-run only the steps that produced its artifact, and only when the artifact is missing or its pin no longer matches (`pin --check`), pin it again (step 2) when you re-ran them, then write `gate-<id>.md` again if it is gone and ask again.
- A pre-approval does not lapse; step 3 checks it again.
- An owner's "done" does not lapse: resume at the post-gate part, which verifies.
- A `Task N post-gate: dispatched` (or `started`) line with neither a completion, a record commit nor a `Gate <id>: approval void` line after it means the part may already have acted: never re-run it blindly; make it an unforeseen gate that shows its report.

The section stays in the plan until the next pause rewrites it or `build:finish` removes the plan.

## Ledger lines

The ledger holds summaries and identifiers, never a secret: a pause commits it to the branch.
Every `<time>` in a line is the output of `date +%Y-%m-%dT%H:%M:%S%z` run when the line is written.

```text
Task 6 pre-gate: complete (no commits; pins bootstrap.tfplan sha256:<64 hex digits>)
Gate apply-state-bucket: waiting for owner
Gate apply-state-bucket: owner 2026-09-27T14:51:55+0800: "Go ahead and apply!"
Gate apply-state-bucket: pre-approved (plan index); Expected lines matched
Gate apply-state-bucket: pre-approval void (Step 3 expected 6 to add, got 7 to add); asking
Task 6 post-gate: dispatched
Gate apply-state-bucket: approval void (pin check: bootstrap.tfplan changed)
Pause 2026-09-27T14:11:02+0800: resume at Task 6 pre-gate; removed backend_override.tf, bootstrap.tfplan
Resume 2026-09-27T14:39:40+0800: recreated the ledger from the plan's Execution status
Task 6: evidence review clean
Task 6: complete (commits 6033d2e..a1b2c3d, evidence review clean)
Task 7: complete (recovered from git log: b4c5d6e)
```

`Task 6 pre-gate:` never matches the resume check for `Task 6: complete`, so a finished pre-gate part never reads as a finished task.
