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
Task 6 pre-gate: complete (no commits; pins bootstrap.tfplan sha256:<64 hex digits>)
Gate apply-state-bucket: waiting for owner
Gate apply-state-bucket: owner 2026-09-27T14:51:55+0800: "Go ahead and apply!"
Gate apply-state-bucket: pre-approved (plan index); Expected lines matched
Gate apply-state-bucket: pre-approval void (Step 3 expected 6 to add, got 7 to add); asking
Task 6 post-gate: dispatched
Pause 2026-09-27T14:11:02+0800: resume at Task 6 pre-gate; removed backend_override.tf, bootstrap.tfplan
Resume 2026-09-27T14:39:40+0800: recreated the ledger from the plan's Execution status
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

Every edit to an accepted ADR adds one line to a `## Change log` section at its end, which the first edit creates: the date and the nature of the change.

```markdown
## Change log

- 2026-09-30: "gates" became "review gates", matching `CONCEPTS.md`; added a pointer to ADR 0018.
```

A `Status:` line is an edit too and gets its line.
An ADR is accepted once it is on the default branch; edits on the branch that introduces it are part of writing it and add no line.

Under this rule, ADR 0016 gets "review gates" for "gates", a pointer to ADR 0018 and its first change log line; its ledger sentence stays, and ADR 0018 records the exception.

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

`shared/ADR-FORMAT.md` and `plugins/conventions/skills/adr/SKILL.md`: the ADR edit test, the `## Change log` section (ADR-FORMAT.md lists it with the optional sections, as required once an accepted ADR is edited), and when an ADR counts as accepted.

`plugins/conventions/skills/engineering/SKILL.md`: "Ask before any other effect outside the branch" gains that an owner gate pre-approved by ID counts as asking.

`docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`: "review gates", the pointer to ADR 0018, and a `## Change log` with that edit's line.

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

## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` (recommended) or `build:execute` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the build skills owner gates: a gate step and index in plans, a protocol both executors follow at every stop, pause and resume across sessions, an evidence review, and record commits, plus the ADR edit test the ADR 0016 wording change needs.

**Architecture:** Three new or changed bash scripts in `build:delegate` (`pin`, `task-brief`, `execution-status`) carry the mechanics, proven by one fixture test file that `devenv test` runs.
One protocol document, `references/owner-gates.md`, holds the steps both executors follow, and the skill texts of `plan`, `delegate`, `execute` and `finish`, the shared `WORKFLOW.md` and `conventions:engineering` point at it.
A rehearsal with nested headless sessions checks the protocol end to end before the pull request.

**Tech stack:** Bash and POSIX awk (the scripts run under GNU awk, mawk and BSD awk), Markdown skill text, devenv for the test wiring, the `claude` CLI for the rehearsal.

**Spec:** The `## Design` section of this file, with ADR 0018 and the `CONCEPTS.md` terms review gate, owner gate and pre-approval.

### Owner Gates

None.

### Global Constraints

- Markdown: one sentence per line; no em dashes, no en dashes, no curly quotes (the `prose-lint` hook); every fenced block names its language.
- Shipped text (everything under `plugins/` and `shared/`) stays agent-neutral and never names this repository's ADRs, paths or rules; only `CLAUDE.md`, `docs/` and `devenv.nix` may.
- Scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`, are shellcheck clean, keep their exec bit, use only POSIX awk, and print the path they wrote on stdout and their summary on stderr. Skill text runs them through `bash`, because some plugin installers strip exec bits.
- Gate marker: `` - [ ] **Step N: Owner gate `<id>`** `` (a ticked `[x]` counts too). The ID matches `^[a-z0-9]+(-[a-z0-9]+)*$` and is unique in the plan.
- Gate fields, one line each, directly under the marker and indented two spaces: `- Show:`, `- Acts on:` (optional), `- Ask:`, `- Performed by: agent,` or `- Performed by: owner,`, `- Consequences:`, `- On no:`, each followed by a space and its value.
- Index: `### Owner Gates`, the first subsection of `## Plan`, holding the table `| ID | Task | Performed by | Consequences | Pre-approved |` or the single line `None.`.
- Workspace files: `task-N-pre-gate-brief.md`, `task-N-post-gate-brief.md`, `task-N-pre-gate-report.md`, `task-N-post-gate-report.md`, `gate-<id>.md`.
- Ledger lines, exactly: `Task N pre-gate: complete (no commits; pins <file> sha256:<hex>, ...)`; `Gate <id>: waiting for owner`; `Gate <id>: owner <time>: "<answer>"`; `Gate <id>: pre-approved (plan index); Expected lines matched`; `Gate <id>: pre-approval void (<reason>); asking`; `Task N post-gate: dispatched` (`started` in `build:execute`); `Pause <time>: resume at Task N pre-gate; removed <files>`; `Resume <time>: <what execution-status restore printed>`; `State: owner answered <id>: "<answer>"`; `Task N: complete (commits <base7>..<head7>, evidence review clean)`.
- Times come from `date +%Y-%m-%dT%H:%M:%S%z`, for example `2026-09-27T14:51:55+0800`.
- A pin is `sha256:` and 64 lowercase hex digits; ledgers and dispatches carry it whole, and the gate message shows the first 12 digits.
- Commit messages: `docs(plan): record pre-approved owner gates`, `docs(plan): pause at gate <id>`; a record commit is Conventional Commits with the evidence in its body. No commit message mentions an agent or carries a `Co-Authored-By` trailer, and none uses dashes or curly quotes.
- Execution status: the heading `## Execution status`, a line `Resume at: Task N pre-gate (gate <id>)`, and the ledger verbatim in a `` ````text `` fence.
- Every commit that changes a plugin bumps that plugin's `plugin.json` version by one minor step and adds `## <version> - <date +%F>` with its entry at the top of that plugin's `CHANGELOG.md`, in the same commit. Starting versions: `build` 0.6.0, `conventions` 0.9.1, `discover` 0.4.0.
- The four `build` skills are vendored: every change to one adds a bullet to its `UPSTREAM.md` under "Local patches", in the same commit.
- The full check is `devenv test`; hook evidence is `prek run --all-files`, or `prek run --files <paths>`.

### Review Focus

- A plan written before owner gates existed (no Owner Gates index, no gate): every task extracts exactly as before. Test in Task 4.
- A gate step the executor already ticked (`- [x]`): `task-brief` still recognizes it. Test in Task 4.
- A gate field whose value holds a colon or backticks (a command such as `apply --set key:value`): the field is still read by its name. Test in Task 4.
- A ledger line holding characters that shells, sed or awk treat specially (`&`, `\`, `$`, quotes): `execution-status` writes and restores it byte for byte. Test in Task 5.
- A plan whose last line has no trailing newline: `execution-status write` still produces a well-formed section after a blank line. Test in Task 5.

### Task 1: The ADR edit test and the change log

**Files:**

- Modify: `plugins/conventions/skills/adr/SKILL.md` (the bullet "An accepted ADR is never rewritten.")
- Modify: `shared/ADR-FORMAT.md` (the "Optional sections" list, and a new section after it)
- Modify: `plugins/conventions/.claude-plugin/plugin.json`, `plugins/conventions/CHANGELOG.md`
- Modify: `plugins/discover/.claude-plugin/plugin.json`, `plugins/discover/CHANGELOG.md` (`ADR-FORMAT.md` is symlinked into `discover:domain-model`)

**Interfaces:**

- Consumes: nothing.
- Produces: the rule Task 2 applies to ADR 0016: an accepted ADR may be edited only when someone who acted on the old text would act the same way on the new one, and every edit adds a dated line to its `## Change log`.

- [ ] **Step 1: Show that the old rule is in place**

Run: `grep -c 'An accepted ADR is never rewritten' plugins/conventions/skills/adr/SKILL.md; grep -c '^## Editing an accepted ADR$' shared/ADR-FORMAT.md`
Expected: `1`, then `0`.

- [ ] **Step 2: Replace the rule in `conventions:adr`**

In `plugins/conventions/skills/adr/SKILL.md`, replace the line

```markdown
- An accepted ADR is never rewritten. A change of mind is a new ADR, and the old one gets a `Status: superseded by NNNN` line.
```

with these two lines:

```markdown
- An ADR is accepted once it is on the default branch. An edit to an accepted ADR is allowed only when someone who acted on the old text would act the same way on the new one: terminology aligned with `CONCEPTS.md`, a typo, a broken link, a forward pointer, a `Status:` line. A change of mind (anything that widens, narrows or reverses the decision, its reasons or its consequences) is a new ADR, and the old one gets a `Status: superseded by NNNN` line or a forward pointer.
- Every edit to an accepted ADR adds a dated line saying what changed to a `## Change log` section at its end, which the first edit creates.
```

- [ ] **Step 3: Add the section to `ADR-FORMAT.md`**

In `shared/ADR-FORMAT.md`, after the line that starts ``- A `Status:` line`` in "Optional sections", add:

```markdown
- `## Change log`: required once an accepted ADR is edited; see [Editing an accepted ADR](#editing-an-accepted-adr).
```

Then insert this section between "Optional sections" and `## When to write one`, with one blank line before and after:

````markdown
## Editing an accepted ADR

An ADR is accepted once it is on the default branch; edits on the branch that introduces it are part of writing it.
An accepted ADR records what was decided and why, and git keeps its original wording, so an edit is allowed only when someone who acted on the old text would act exactly the same way on the new text:

- aligning its terminology with `CONCEPTS.md`;
- fixing a typo or a broken link;
- adding a forward pointer, such as "See also ADR 0012", or a `Status:` line.

Anything that widens, narrows or reverses the decision, its reasons or its consequences is a new ADR, and the old one gets a `Status:` line or a forward pointer.

Every edit adds one line to a `## Change log` section at the end of the ADR, which the first edit creates: the date and the nature of the change.

```md
## Change log

- 2026-10-02: "customer" became "client", matching `CONCEPTS.md`; added a pointer to ADR 0012.
```
````

- [ ] **Step 4: Bump both plugins**

Set `"version": "0.10.0"` in `plugins/conventions/.claude-plugin/plugin.json` and `"version": "0.5.0"` in `plugins/discover/.claude-plugin/plugin.json`.
At the top of `plugins/conventions/CHANGELOG.md`, below its header paragraph, add (the date is today's `date +%F`):

```markdown
## 0.10.0 - 2026-09-30

- `adr` replaces "an accepted ADR is never rewritten" with a test: an edit is allowed when someone who acted on the old text would act the same way on the new one (terminology aligned with `CONCEPTS.md`, a typo, a broken link, a forward pointer, a `Status:` line), and a change of mind is still a new ADR. Every edit adds a dated line to a `## Change log` section at the end of the ADR, and an ADR counts as accepted once it is on the default branch. `ADR-FORMAT.md` gains the matching section.
```

At the top of `plugins/discover/CHANGELOG.md`, below its header paragraph, add:

```markdown
## 0.5.0 - 2026-09-30

- `ADR-FORMAT.md`, symlinked into `domain-model`, says when an accepted ADR may be edited and that every edit adds a line to its `## Change log`.
```

- [ ] **Step 5: Show that the new rule is in place**

Run: `grep -c 'An accepted ADR is never rewritten' plugins/conventions/skills/adr/SKILL.md; grep -c '^## Editing an accepted ADR$' shared/ADR-FORMAT.md`
Expected: `0`, then `1`.

Run: `prek run --files plugins/conventions/skills/adr/SKILL.md shared/ADR-FORMAT.md plugins/conventions/CHANGELOG.md plugins/discover/CHANGELOG.md plugins/conventions/.claude-plugin/plugin.json plugins/discover/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`.

- [ ] **Step 6: Commit**

```bash
git add plugins/conventions/skills/adr/SKILL.md shared/ADR-FORMAT.md plugins/conventions/.claude-plugin/plugin.json plugins/conventions/CHANGELOG.md plugins/discover/.claude-plugin/plugin.json plugins/discover/CHANGELOG.md
git commit -m "feat(conventions,discover): allow ADR edits that keep the decision, with a change log"
```

### Task 2: ADR 0016 names its gates review gates

**Files:**

- Modify: `docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`

**Interfaces:**

- Consumes: the ADR edit test from Task 1; ADR 0018 (committed on this branch before the plan).
- Produces: nothing later tasks read.

The edit passes Task 1's test: it renames "gates" to the `CONCEPTS.md` term and adds a pointer, and nobody who acted on the old text would act differently.
The ledger sentence ("never in git") stays as it is; ADR 0018 records its exception.
The file name stays, so every link to it keeps working.

- [ ] **Step 1: Show the old wording**

Run: `grep -c 'review gates' docs/adr/0016-planned-work-is-reviewed-at-two-gates.md; grep -c '^## Change log$' docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`
Expected: `0`, then `0`.

- [ ] **Step 2: Rename the gates**

In `docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`, make exactly these replacements:

- In the title, `reviewed at two gates, the plan and the branch` becomes `reviewed at two review gates, the plan and the branch`.
- `We review planned work at two gates:` becomes `We review planned work at two review gates:`.
- `between the gates the executor commits per task` becomes `between the review gates the executor commits per task`.
- `with the pull request as its last gate:` becomes `with the pull request as its last review gate:`.

- [ ] **Step 3: Add the pointer and the change log**

After the last line of the opening paragraph (the line that ends `never in git.`), add on its own line:

```markdown
See also [ADR 0018](0018-owner-gates-are-declared-in-the-plan-and-pre-approved-by-name.md): owner gates inside a plan's execution, and the copy of the ledger in the plan when a run pauses.
```

At the end of the file, after one blank line, add (the date is today's `date +%F`):

```markdown
## Change log

- 2026-09-30: "gates" became "review gates", matching `CONCEPTS.md`; added a pointer to ADR 0018.
```

- [ ] **Step 4: Show the new wording**

Run: `grep -c 'review gate' docs/adr/0016-planned-work-is-reviewed-at-two-gates.md; grep -c '^## Change log$' docs/adr/0016-planned-work-is-reviewed-at-two-gates.md; grep -c ' two gates\| the gates \| last gate' docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`
Expected: `4` (the three lines with "review gates" and the change log line; `grep -c` counts lines), then `1`, then `0`.

Run: `prek run --files docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`
Expected: every hook `Passed` or `Skipped`.

- [ ] **Step 5: Commit**

```bash
git add docs/adr/0016-planned-work-is-reviewed-at-two-gates.md
git commit -m "docs(adr): call ADR 0016's gates review gates and point to ADR 0018"
```

### Task 3: The `pin` script and the build script tests

**Files:**

- Create: `plugins/build/tests/scripts.sh` (executable)
- Create: `plugins/build/skills/delegate/scripts/pin` (executable)
- Modify: `devenv.nix` (a `testBuildScripts` binding and a line in `enterTest`)
- Modify: `CLAUDE.md` (the sentence saying what `devenv test` runs)
- Modify: `plugins/build/skills/delegate/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: `plugins/build/skills/delegate/scripts/review-package` and `workspace`, unchanged.
- Produces: `bash <delegate>/scripts/pin FILE...` prints one `sha256:<64 hex> <file>` line per file; `pin --check sha256:<hex> FILE` exits 0 on a match, 1 on a mismatch, 2 on a malformed pin, a missing file or no hash tool.
- Produces: `plugins/build/tests/scripts.sh`, whose later sections go immediately before the line `# --- Summary ---...`, with the helpers `check <label> <command...>`, `equals <actual> <expected>`, `contains <text> <needle>`, `lacks <text> <needle>`, `run <command...>` (sets `out`, `err`, `code`) and `new_repo <name>` (prints the path of a fresh repository with `docs/plans/`), and the variables `build`, `delegate` and `tmp`.
- Produces: `devenv test` runs that file through the wrapper `test-build-scripts`.

- [ ] **Step 1: Show that `devenv test` runs no build script tests yet**

Run: `DEVENV_NO_AI_AGENT=1 devenv test >tmp/devenv-test.log 2>&1; grep -c 'build scripts:' tmp/devenv-test.log`
Expected: `0` (`devenv test` itself passes; `tmp/` is the gitignored scratch directory).

- [ ] **Step 2: Write the test file**

Create `plugins/build/tests/scripts.sh` with exactly this content, then `chmod +x plugins/build/tests/scripts.sh`:

```bash
#!/usr/bin/env bash
# Exercise the build plugin's scripts against throwaway git repositories and
# plans. The repository's full check runs this file.
set -euo pipefail

build=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
delegate=$build/skills/delegate/scripts
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

# --- Assertions --------------------------------------------------------------

check() {
  local label=$1
  shift
  if "$@"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

equals() {
  [[ "$1" == "$2" ]] || {
    echo "  expected: $2"
    echo "  actual:   $1"
    return 1
  }
}

contains() {
  grep -qF -- "$2" <<<"$1" || {
    echo "  missing: $2"
    return 1
  }
}

lacks() {
  ! grep -qF -- "$2" <<<"$1" || {
    echo "  unexpected: $2"
    return 1
  }
}

# run <command>...: run a command, capturing stdout, stderr and the exit code
# in out, err and code.
run() {
  code=0
  out=$("$@" 2>"$tmp/stderr" </dev/null) || code=$?
  err=$(<"$tmp/stderr")
}

# new_repo <name>: a git repository with one commit, printed as its path.
new_repo() {
  local repo=$tmp/$1
  mkdir -p "$repo/docs/plans"
  git -C "$repo" init -q -b main
  git -C "$repo" commit -q --allow-empty -m "chore: start"
  echo "$repo"
}

# --- pin ---------------------------------------------------------------------

repo=$(new_repo pin)
printf 'hello\n' >"$repo/artifact.txt"
hello=5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
run bash "$delegate/pin" "$repo/artifact.txt"
check "pin: prints sha256:<hex> and the file" \
  equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/artifact.txt"
check "pin --check: a matching pin exits 0 and prints nothing" \
  equals "$code|$out|$err" "0||"
printf 'hello!\n' >"$repo/edited.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/edited.txt"
check "pin --check: an edited file exits 1 and names both hashes" \
  equals "$code|$(grep -c "pinned sha256:$hello, found sha256:" <<<"$err")" "1|1"
run bash "$delegate/pin" --check "sha256:abc" "$repo/artifact.txt"
check "pin --check: a malformed pin is a usage error" \
  equals "$code" "2"
run bash "$delegate/pin" "$repo/missing.txt"
check "pin: a missing file is an error, with nothing printed" \
  equals "$code|$out" "2|"
for tool in sha256sum shasum; do
  only=$tmp/only-$tool
  mkdir -p "$only"
  ln -s "$(command -v bash)" "$only/bash"
  ln -s "$(command -v "$tool")" "$only/$tool"
  run env -i PATH="$only" "$only/bash" "$delegate/pin" "$repo/artifact.txt"
  check "pin: works with $tool alone" \
    equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
done
none=$tmp/no-hash-tool
mkdir -p "$none"
ln -s "$(command -v bash)" "$none/bash"
run env -i PATH="$none" "$none/bash" "$delegate/pin" "$repo/artifact.txt"
check "pin: without a hash tool, exits 2 and says so" \
  equals "$code|$err" "2|pin: neither sha256sum nor shasum is on PATH"

# --- review-package ----------------------------------------------------------

repo=$(new_repo review-package)
printf '# Plan\n' >"$repo/docs/plans/2026-01-01-demo.md"
git -C "$repo" add docs/plans/2026-01-01-demo.md
git -C "$repo" commit -q -m "docs: add the plan"
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" commit -q --allow-empty -m "chore: record the apply of demo.tfplan" \
  -m "Gate apply-demo: owner 2026-01-01T10:00:00+0000: \"yes\""
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md "$3" HEAD' _ "$repo" "$delegate" "$base"
package=$(cat "$out" 2>/dev/null || true)
check "review-package: a range holding only an empty record commit makes a package" \
  equals "$code" "0"
check "review-package: the package shows the record commit's evidence" \
  contains "$package" 'Gate apply-demo: owner 2026-01-01T10:00:00+0000: "yes"'
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md HEAD HEAD' _ "$repo" "$delegate"
check "review-package: an empty range is still refused" \
  equals "$code" "3"

# --- Summary -----------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
  echo "build scripts: $failures failure(s)"
  exit 1
fi
echo "build scripts: all passed"
```

- [ ] **Step 3: Run it to see the `pin` checks fail**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 1; `FAIL:` on all eight `pin` checks (the script does not exist yet), `ok:` on the three `review-package` checks, and the last line `build scripts: 8 failure(s)`.

- [ ] **Step 4: Write `pin`**

Create `plugins/build/skills/delegate/scripts/pin` with exactly this content, then `chmod +x plugins/build/skills/delegate/scripts/pin`:

```bash
#!/usr/bin/env bash
# Pin files for an owner gate: print each file's sha256 in the form the
# ledger, the gate message and the record commit use, or check a file against
# a recorded pin before the post-gate steps act on it. An approval covers
# exactly the pinned bytes, so a regenerated or edited artifact fails the
# check even when it reads the same.
#
# Usage: pin FILE...
#        pin --check sha256:<64 hex digits> FILE
# Prints one "sha256:<hex> <file>" line per file. --check prints nothing on a
# match and exits 1 on a mismatch, naming both hashes on stderr.
# Exit: 1 on a mismatch, 2 on a usage error, a missing file or no hash tool.
set -euo pipefail

usage() {
  echo "usage: pin FILE... | pin --check sha256:<hex> FILE" >&2
  exit 2
}

# sha256sum on Linux, shasum on macOS, chosen once here: an exit inside the
# command substitution below would leave only that subshell. Reading stdin
# keeps the file name out of their output, which both print as "<hex>  -".
if command -v sha256sum >/dev/null 2>&1; then
  hasher=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  hasher=(shasum -a 256)
else
  echo "pin: neither sha256sum nor shasum is on PATH" >&2
  exit 2
fi

hash_of() {
  local out
  out=$("${hasher[@]}" <"$1")
  printf '%s\n' "${out%% *}"
}

require_file() {
  [ -f "$1" ] || {
    echo "pin: no such file: $1" >&2
    exit 2
  }
}

[ $# -ge 1 ] || usage

if [ "$1" = "--check" ]; then
  [ $# -eq 3 ] || usage
  want=$2
  file=$3
  [[ $want =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "pin: not a pin: $want" >&2
    exit 2
  }
  require_file "$file"
  got="sha256:$(hash_of "$file")"
  if [ "$got" != "$want" ]; then
    echo "pin: $file does not match its pin: pinned $want, found $got" >&2
    exit 1
  fi
  exit 0
fi

for f in "$@"; do
  require_file "$f"
done
for f in "$@"; do
  printf 'sha256:%s %s\n' "$(hash_of "$f")" "$f"
done
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 0, eleven `ok:` lines and the last line `build scripts: all passed`.

Run: `shellcheck plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/pin`
Expected: no output, exit 0.

- [ ] **Step 6: Run the tests from `devenv test`**

In `devenv.nix`, add this binding inside the `let` block, directly after the `testRepoHooks` binding:

```nix
  # Fixture tests for the build plugin's scripts. perl provides shasum, so
  # the tests can run pin with each hash tool alone.
  testBuildScripts = pkgs.writeShellApplication {
    name = "test-build-scripts";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.perl
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/scripts.sh" "$@"'';
  };
```

and add this line at the end of `enterTest`, after `${lib.getExe testRepoHooks}`:

```nix
    ${lib.getExe testBuildScripts}
```

In `CLAUDE.md`, replace

```markdown
`devenv test` runs every git hook on every file, then `validate-marketplace`, `validate-prerequisites` and the fixture tests of the validators.
```

with

```markdown
`devenv test` runs every git hook on every file, then `validate-marketplace`, `validate-prerequisites` and the fixture tests of the validators, the `repo` plugin's hooks and the `build` plugin's scripts.
```

- [ ] **Step 7: Show that `devenv test` now runs them**

Run: `DEVENV_NO_AI_AGENT=1 devenv test >tmp/devenv-test.log 2>&1; echo "exit $?"; grep -c 'build scripts: all passed' tmp/devenv-test.log`
Expected: `exit 0`, then `1`.

- [ ] **Step 8: Bump `build` and record the patch**

Set `"version": "0.7.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, below its header paragraph, add (the date is today's `date +%F`):

```markdown
## 0.7.0 - 2026-09-30

- `delegate` gains `scripts/pin`, which prints a file's sha256 in the form an owner gate records (`sha256:<hex> <file>`) and checks a file against a recorded pin with `--check`, using `sha256sum` or `shasum`. The build scripts have fixture tests in `tests/scripts.sh`, which also prove that `review-package` accepts a range holding only an empty record commit.
```

At the end of "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`, add:

```markdown
- Added `scripts/pin`, which is not upstream: it prints `sha256:<hex> <file>` for each file and checks a file against a pin with `--check`, using `sha256sum` or `shasum -a 256`; the owner gate protocol pins what an approval covers with it.
```

- [ ] **Step 9: Commit**

Run: `prek run --files plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/pin devenv.nix CLAUDE.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped` (`nixfmt` may reformat `devenv.nix`; stage its result and run again).

```bash
git add plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/pin devenv.nix CLAUDE.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): add the pin script and fixture tests for the build scripts"
```

### Task 4: `task-brief` ends tasks at their level and splits gated tasks

**Files:**

- Modify: `plugins/build/skills/delegate/scripts/task-brief` (replaced whole)
- Modify: `plugins/build/tests/scripts.sh` (a `task-brief` section)
- Modify: `plugins/build/skills/delegate/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: the test helpers from Task 3.
- Produces: `task-brief PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate] [OUTFILE]`.
  Without `--part` it writes `task-N-brief.md`; with it, `task-N-pre-gate-brief.md` or `task-N-post-gate-brief.md`.
  The pre-gate brief is the task's header (everything before its first step), the steps before the gate, the gate block, a blank line and `Stop here: the controller takes the gate.`; the post-gate brief is the header, the gate block and the steps after it; both end with the Global Constraints.
  Exit 3, with `task-brief: <reason>` on stderr and no brief written, for a missing task, a malformed gate, a gated task without `--part` and an ungated task with it.
- Produces: the test helper `fixture`, which prints a plan with an ungated Task 1, a gated Task 2 (gate `apply-thing`), an ungated Task 3 and an `## Execution status`; Task 8 reuses it.

- [ ] **Step 1: Add the `task-brief` tests**

In `plugins/build/tests/scripts.sh`, insert this section immediately before the line `# --- Summary ---...`, keeping one blank line between sections:

```bash
# --- task-brief --------------------------------------------------------------

# The fixture's fences are tildes; a copy with backticks proves both kinds.
# Task 1 holds a fenced fake task heading and gate after an inner fence, which
# must stay text; the plan ends with an Execution status after the last task.
fixture() {
  cat <<'EOF'
# Fixture

## Design

Nothing here.

## Plan

### Owner Gates

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-thing` | 2 | agent | creates the thing | no |

### Global Constraints

- Constraint one.

### Task 1: Ungated

**Files:**

- Create: `a.txt`

- [ ] **Step 1: Write a**

~~~~markdown
~~~bash
### Task 9: Inside an inner fence
~~~
- [ ] **Step 2: Owner gate `fenced-gate`**
~~~~

- [ ] **Step 2: Commit**

### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 1: Plan the thing**

Run: `make-plan > thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

- [ ] **Step 3: Apply**

Run: `apply thing.plan`

- [ ] **Step 4: Record**

### Task 3: Last

- [ ] **Step 1: Finish**

## Execution status

Resume at: Task 2 pre-gate (gate apply-thing)
EOF
}

repo=$(new_repo task-brief)
plan=$repo/docs/plans/2026-01-01-fixture.md
fixture >"$plan"
brief() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$delegate/task-brief" "$@"
  body=$(cat "$out" 2>/dev/null || true)
}

brief "$plan" 1
check "task-brief: an ungated task prints the path of task-1-brief.md" \
  equals "$code|${out##*/}" "0|task-1-brief.md"
check "task-brief: a fenced task heading and gate stay inside the task" \
  contains "$body" "- [ ] **Step 2: Commit**"
check "task-brief: the task stops at the next task" \
  lacks "$body" "### Task 2: Gated"
check "task-brief: the Global Constraints follow the task" \
  equals "$(tail -n 3 <<<"$body")" $'### Global Constraints\n\n- Constraint one.'

fixture | tr '~' '`' >"$repo/docs/plans/2026-01-01-backticks.md"
brief "$repo/docs/plans/2026-01-01-backticks.md" 1
check "task-brief: backtick fences inside a longer backtick fence stay text" \
  equals "$code|$(grep -c 'Step 2: Commit' <<<"$body")" "0|1"

brief "$plan" 2
check "task-brief: a gated task without --part is refused" \
  equals "$code|$err" "3|task-brief: task 2 has owner gate \`apply-thing\`; pass --part pre-gate or --part post-gate"
check "task-brief: a refusal writes no brief" \
  equals "$(compgen -G "$repo/tmp/build/2026-01-01-fixture/task-2*" || true)" ""

brief "$plan" 2 --part pre-gate
check "task-brief: the pre-gate brief is task-2-pre-gate-brief.md" \
  equals "$code|${out##*/}" "0|task-2-pre-gate-brief.md"
check "task-brief: the pre-gate brief holds the header, the pre-gate steps, the gate and the stop line" \
  equals "$(sed -n '1,/^Stop here/p' <<<"$body")" "$(cat <<'EOF'
### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 1: Plan the thing**

Run: `make-plan > thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

Stop here: the controller takes the gate.
EOF
)"
check "task-brief: the pre-gate brief leaves out the post-gate steps" \
  equals "$code|$(grep -c 'Step 3: Apply' <<<"$body")" "0|0"
check "task-brief: the pre-gate brief ends with the Global Constraints" \
  equals "$(tail -n 1 <<<"$body")" "- Constraint one."

brief "$plan" 2 --part post-gate
check "task-brief: the post-gate brief holds the header, the gate and the post-gate steps" \
  equals "$(sed -n '1,/^- \[ \] \*\*Step 4/p' <<<"$body")" "$(cat <<'EOF'
### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

- [ ] **Step 3: Apply**

Run: `apply thing.plan`

- [ ] **Step 4: Record**
EOF
)"
check "task-brief: the post-gate brief leaves out the pre-gate steps" \
  equals "$code|$(grep -c 'Step 1: Plan the thing' <<<"$body")" "0|0"
check "task-brief: the post-gate brief stops at the next task" \
  equals "$code|$(grep -c 'Task 3: Last' <<<"$body")" "0|0"

brief "$plan" 3
check "task-brief: the last task stops before the Execution status" \
  equals "$code|$(grep -c 'Step 1: Finish' <<<"$body")|$(grep -c 'Resume at:' <<<"$body")" "0|1|0"

brief "$plan" 1 --part pre-gate
check "task-brief: --part on an ungated task is refused" \
  equals "$code|$err" "3|task-brief: task 1 has no owner gate; leave out --part"

check "task-brief: a field value holding a colon and backticks is read by its field name" \
  contains "$(cat "$repo/tmp/build/2026-01-01-fixture/task-2-pre-gate-brief.md")" "  - Performed by: agent, \`apply --set key:value thing.plan\`"

brief "$plan" 1
with_index=$body
fixture | sed '/^### Owner Gates$/,/^### Global Constraints$/{/^### Global Constraints$/!d;}' | sed '/^### Task 2: Gated$/,$d' >"$plan"
brief "$plan" 1
check "task-brief: a plan without an Owner Gates index or a gate extracts its tasks as before" \
  equals "$code|$body" "0|$with_index"

fixture | sed 's/^- \[ \] \*\*Step 2: Owner gate/- [x] **Step 2: Owner gate/' >"$plan"
brief "$plan" 2 --part pre-gate
check "task-brief: a ticked gate step is still a gate" \
  equals "$code|$(grep -c '^- \[x\] \*\*Step 2: Owner gate' <<<"$body")|$(grep -c '^Stop here: the controller takes the gate.$' <<<"$body")" "0|1|1"
fixture >"$plan"

# refused <label> <expected stderr> <sed script>: task 2 of a fixture edited by
# the sed script is refused with exactly that message.
refused() {
  local label=$1 expected=$2 edit=$3
  fixture | sed "$edit" >"$plan"
  brief "$plan" 2 --part pre-gate
  check "task-brief refuses $label" equals "$code|$err" "3|task-brief: $expected"
}
# Each case is three lines: what is refused, the exact message, and the sed
# script that breaks the fixture that way.
while read -r label && read -r expected && read -r edit; do
  refused "$label" "$expected" "$edit"
done <<'EOF'
a second gate in the task
task 2 has 2 owner gates; a task has at most one
s/^- \[ \] \*\*Step 4: Record\*\*$/- [ ] **Step 4: Owner gate `record-thing`**/
a missing field
owner gate `apply-thing`: the field Consequences is missing
/^  - Consequences:/d
a field given twice
owner gate `apply-thing`: the field Ask appears twice
s/^  - On no: .*/  - Ask: "Really?"/
a performer that is neither agent nor owner
owner gate `apply-thing`: Performed by must start with "agent, " or "owner, "
s/^  - Performed by: agent, /  - Performed by: whoever, /
an ID missing from the index
owner gate `apply-thing` is missing from the Owner Gates index
s/^| `apply-thing` |/| `apply-other` |/
an ID that is not kebab-case
owner gate `Apply_Thing`: the ID must be kebab-case
s/Owner gate `apply-thing`/Owner gate `Apply_Thing`/
a duplicate ID
owner gate `apply-thing` appears 2 times in the plan; an ID is unique
s/^- \[ \] \*\*Step 2: Commit\*\*$/- [ ] **Step 2: Owner gate `apply-thing`**/
a malformed marker
task 2: malformed owner gate marker: - [ ] **Step 2: Owner gate apply-thing**
s/^- \[ \] \*\*Step 2: Owner gate `apply-thing`\*\*$/- [ ] **Step 2: Owner gate apply-thing**/
EOF
fixture >"$plan"

brief "$plan" 7
check "task-brief: a missing task exits 3" \
  equals "$code|$err" "3|task-brief: task 7 not found (no heading matching Task 7)"
```

- [ ] **Step 2: Run them to see them fail**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 1, with `FAIL:` on 24 of the 28 `task-brief` checks.
The four that already hold are `an ungated task prints the path of task-1-brief.md`, `the task stops at the next task`, `the Global Constraints follow the task` and `a plan without an Owner Gates index or a gate extracts its tasks as before`.
The last line is `build scripts: 24 failure(s)`.

- [ ] **Step 3: Replace `task-brief`**

Replace the whole of `plugins/build/skills/delegate/scripts/task-brief` with exactly this content, keeping its exec bit:

```bash
#!/usr/bin/env bash
# Extract one task's full text from an implementation plan, followed by the
# plan's Global Constraints section, into a file the implementer reads in one
# call, so neither has to be pasted through the controller's context. Every
# task's requirements implicitly include the Global Constraints; a plan
# without that section yields a brief without it.
#
# A task runs from its heading to the next heading of the same or a higher
# level outside a code fence, so a section after the last task (such as an
# Execution status) never leaks into its brief.
#
# A task with an owner gate (a step `- [ ] **Step N: Owner gate `<id>`**`
# followed by its field lines) is extracted in two parts. --part pre-gate
# yields the task's header, the steps before the gate, the gate block and a
# line that stops the implementer there; --part post-gate yields the header,
# the gate block and the steps after it. A malformed gate is refused before
# anything is written, so it fails before a dispatch rather than at the gate.
#
# Usage: task-brief PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate] [OUTFILE]
# Default OUTFILE: <repo-root>/tmp/build/<plan-basename>/task-<N>-brief.md, or
# task-<N>-pre-gate-brief.md and task-<N>-post-gate-brief.md for the parts
# (one per task and part, per plan and per worktree; every call writes the
# same plan text, so regenerating it is harmless).
# Prints the brief's path on stdout and a summary on stderr.
# Exit: 2 on a usage error; 3 when the task is missing, its gate is
# malformed, or the part does not fit the task.
set -euo pipefail

usage() {
  echo "usage: task-brief PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate] [OUTFILE]" >&2
  exit 2
}

[ $# -ge 2 ] || usage
plan=$1
n=$2
shift 2
part=""
if [ $# -ge 1 ] && [ "$1" = "--part" ]; then
  [ $# -ge 2 ] || usage
  part=$2
  shift 2
  case "$part" in
    pre-gate | post-gate) ;;
    *) usage ;;
  esac
fi
[ $# -le 1 ] || usage
[ -f "$plan" ] || {
  echo "no such plan file: $plan" >&2
  exit 2
}
case "$n" in
  '' | *[!0-9]*)
    echo "not a task number: $n" >&2
    exit 2
    ;;
esac

name="task-${n}-brief.md"
[ -z "$part" ] || name="task-${n}-${part}-brief.md"
if [ $# -eq 1 ]; then
  out=$1
else
  # Invoke via bash rather than direct exec: some plugin installers strip
  # Unix exec bits when unpacking.
  dir=$("${BASH:-bash}" "$(cd "$(dirname "$0")" && pwd)/workspace" "$plan")
  out="$dir/$name"
fi

# Write next to the brief and move it into place only on success, so a
# refusal never leaves a partial brief behind.
tmpout=$(mktemp "${out}.XXXXXX")
trap 'rm -f "$tmpout"' EXIT

# One fence-aware pass collects the task, the Global Constraints, the IDs in
# the Owner Gates index and every gate marker in the plan. A fence opens with
# three or more backticks or tildes and closes with a run of the same
# character at least as long, so a fence inside a longer fence stays text.
awk -v n="$n" -v part="$part" '
  function fail(msg) {
    printf "task-brief: %s\n", msg | "cat 1>&2"
    close("cat 1>&2")
    failed = 1
    exit 3
  }
  function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
  }
  {
    fenceline = 0
    if (match($0, /^[ \t]*(```+|~~~+)/)) {
      run = substr($0, RSTART, RLENGTH)
      sub(/^[ \t]+/, "", run)
      if (!infence) {
        infence = 1
        fch = substr(run, 1, 1)
        flen = length(run)
        fenceline = 1
      } else if (substr(run, 1, 1) == fch && length(run) >= flen && $0 ~ /^[ \t]*[`~]+[ \t]*$/) {
        infence = 0
        fenceline = 1
      }
    }
    text = !infence && !fenceline
  }
  text && /^#+[ \t]/ {
    level = match($0, /[^#]/) - 1
    if (ingc && level <= gclevel) ingc = 0
    if (inidx && level <= idxlevel) inidx = 0
    if (intask && level <= tasklevel) intask = 0
    if ($0 ~ /^#+[ \t]+Global Constraints[ \t]*$/) { ingc = 1; gclevel = level }
    if ($0 ~ /^#+[ \t]+Owner Gates[ \t]*$/) { inidx = 1; idxlevel = level }
    if ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)")) { intask = 1; tasklevel = level }
  }
  text && inidx && /^\|/ && $0 !~ /^\|[ \t:|-]+$/ {
    split($0, cells, "|")
    id = trim(cells[2])
    gsub(/`/, "", id)
    if (id != "ID") indexed[id] = 1
  }
  text && /^- \[[ xX]\] \*\*Step [0-9]+: Owner gate `[^`]+`\*\*[ \t]*$/ {
    id = $0
    sub(/^[^`]*`/, "", id)
    sub(/`.*$/, "", id)
    seen[id]++
  }
  intask {
    task[++nt] = $0
    if (text && $0 ~ /^- \[[ xX]\] \*\*Step [0-9]+/) {
      if (!firststep) firststep = nt
      if ($0 ~ /^- \[[ xX]\] \*\*Step [0-9]+: Owner gate/) {
        if ($0 !~ /^- \[[ xX]\] \*\*Step [0-9]+: Owner gate `[^`]+`\*\*[ \t]*$/)
          fail("task " n ": malformed owner gate marker: " $0)
        ngates++
        gate = nt
        gid = $0
        sub(/^[^`]*`/, "", gid)
        sub(/`.*$/, "", gid)
      }
    }
  }
  ingc { gc[++ng] = $0 }
  END {
    if (failed) exit 3
    if (nt == 0) fail("task " n " not found (no heading matching Task " n ")")
    while (nt > 0 && task[nt] ~ /^[ \t]*$/) nt--
    if (ngates > 1) fail("task " n " has " ngates " owner gates; a task has at most one")
    if (ngates == 0) {
      if (part != "") fail("task " n " has no owner gate; leave out --part")
      for (i = 1; i <= nt; i++) print task[i]
    } else {
      if (gid !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) fail("owner gate `" gid "`: the ID must be kebab-case")
      if (seen[gid] > 1) fail("owner gate `" gid "` appears " seen[gid] " times in the plan; an ID is unique")
      if (!(gid in indexed)) fail("owner gate `" gid "` is missing from the Owner Gates index")
      # The gate block is the marker and the lines under it that start with
      # two spaces; each field is one of those lines.
      last = gate
      while (last < nt && task[last + 1] ~ /^  /) last++
      for (i = gate + 1; i <= last; i++) {
        if (task[i] ~ /^  - (Show|Acts on|Ask|Performed by|Consequences|On no):[ \t]/) {
          field = task[i]
          sub(/^  - /, "", field)
          sub(/:.*$/, "", field)
          if (field in have) fail("owner gate `" gid "`: the field " field " appears twice")
          have[field] = 1
          if (field == "Performed by" && task[i] !~ /^  - Performed by:[ \t]+(agent|owner), /)
            fail("owner gate `" gid "`: Performed by must start with \"agent, \" or \"owner, \"")
        }
      }
      nreq = split("Show|Ask|Performed by|Consequences|On no", required, "|")
      for (k = 1; k <= nreq; k++)
        if (!(required[k] in have)) fail("owner gate `" gid "`: the field " required[k] " is missing")
      if (part == "") fail("task " n " has owner gate `" gid "`; pass --part pre-gate or --part post-gate")
      if (part == "pre-gate") {
        for (i = 1; i <= last; i++) print task[i]
        print ""
        print "Stop here: the controller takes the gate."
      } else {
        for (i = 1; i < firststep; i++) print task[i]
        for (i = gate; i <= nt; i++) print task[i]
      }
    }
    while (ng > 0 && gc[ng] ~ /^[ \t]*$/) ng--
    if (ng > 0) {
      print ""
      for (i = 1; i <= ng; i++) print gc[i]
    }
  }
' "$plan" >"$tmpout"

mv "$tmpout" "$out"
trap - EXIT
printf '%s\n' "$out"
echo "task-brief: task ${n}${part:+ $part}, $(wc -l <"$out" | tr -d ' ') lines" >&2
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 0, 39 `ok:` lines and the last line `build scripts: all passed`.

Run: `shellcheck plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/task-brief`
Expected: no output, exit 0.

- [ ] **Step 5: Bump `build` and record the patch**

Set `"version": "0.8.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.8.0 - 2026-09-30

- `task-brief` ends a task at the next heading of the same or a higher level, so the last task no longer carries a later section, such as an Execution status, into its brief; it tracks fences by character and length, so a fence inside a longer one stays text. A task with an owner gate is extracted in two parts: `--part pre-gate` writes `task-N-pre-gate-brief.md` (the steps before the gate, the gate and a line that stops the implementer there) and `--part post-gate` writes `task-N-post-gate-brief.md` (the gate and the steps after it). Before it writes anything, it refuses a task with two gates, a gate missing a field or giving one twice, a performer other than `agent` or `owner`, an ID that is not kebab-case, is duplicated or is missing from the Owner Gates index, a gated task without `--part` and an ungated task with it.
```

At the end of "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`, add:

```markdown
- `task-brief`: a task ends at the next heading of the same or a higher level, where upstream ran it to the next task heading and let the last task run to the end of the file; fences are tracked by character and length, where upstream toggled on every line starting with three backticks; `--part pre-gate|post-gate` extracts the two parts of a task with an owner gate; malformed gates are refused with exit 3, and the brief is written to a temporary file that is moved into place only on success.
```

- [ ] **Step 6: Commit**

Run: `prek run --files plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/task-brief plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/task-brief plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): split a gated task into pre-gate and post-gate briefs"
```

### Task 5: `execution-status` keeps a paused run's ledger in the plan

**Files:**

- Create: `plugins/build/skills/delegate/scripts/execution-status` (executable)
- Modify: `plugins/build/tests/scripts.sh` (an `execution-status` section)
- Modify: `plugins/build/skills/delegate/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: the test helpers from Task 3; `scripts/workspace`, unchanged.
- Produces: `execution-status write PLAN_FILE RESUME_AT` writes the section below into the plan, replacing an earlier `## Execution status` section in place or appending one after a blank line, and prints the plan's path:

  `````markdown
  ## Execution status

  The run paused here; `build:finish` removes this section with the rest of the plan.
  The fence holds the ledger verbatim, and an executor recreates `progress.md` from it when its workspace has none.

  Resume at: <RESUME_AT>

  ````text
  <the ledger, verbatim>
  ````
  `````

- Produces: `execution-status restore PLAN_FILE` prints the ledger's path and one of these on stderr, exit 0: `execution-status: recreated the ledger from the plan's Execution status`, `... the ledger matches the plan's Execution status`, `... replaced the ledger with the plan's longer copy`, `... kept the ledger, which extends the plan's copy`, `... <plan> has no Execution status; nothing to restore`.
  It exits 1 when the ledger and the copy disagree or the section has no fenced ledger.

- [ ] **Step 1: Add the `execution-status` tests**

In `plugins/build/tests/scripts.sh`, insert this section immediately before the line `# --- Summary ---...`:

```bash
# --- execution-status --------------------------------------------------------

repo=$(new_repo execution-status)
plan=$repo/docs/plans/2026-01-01-paused.md
printf '# Paused\n\n## Plan\n\n### Task 1: Only\n\n- [ ] **Step 1: Do it**\n' >"$plan"
original=$(cat "$plan")
status() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$delegate/execution-status" "$@"
}
workspace=$(cd "$repo" && bash "$delegate/workspace" "$plan")
ledger=$workspace/progress.md
printf '# build ledger: plan %s\nTask 1 pre-gate: complete (no commits)\n' "$plan" >"$ledger"

status write "$plan" "Task 1 pre-gate (gate do-it)"
check "execution-status write: prints the plan" \
  equals "$code|$out" "0|$plan"
check "execution-status write: appends the section after a blank line" \
  equals "$(cat "$plan")" "$original

## Execution status

The run paused here; \`build:finish\` removes this section with the rest of the plan.
The fence holds the ledger verbatim, and an executor recreates \`progress.md\` from it when its workspace has none.

Resume at: Task 1 pre-gate (gate do-it)

\`\`\`\`text
# build ledger: plan $plan
Task 1 pre-gate: complete (no commits)
\`\`\`\`"

printf 'Gate do-it: waiting for owner\n' >>"$ledger"
status write "$plan" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a second write leaves one section" \
  equals "$(grep -c '^## Execution status' "$plan")" "1"
check "execution-status write: a second write leaves the lines before the section byte for byte" \
  cmp -s <(sed -n '1,/^## Execution status/p' "$plan" | sed '$d') <(printf '%s\n\n' "$original")
check "execution-status write: the new section holds the whole ledger" \
  contains "$(cat "$plan")" "Gate do-it: waiting for owner"

printf '# Middle\n\n## Execution status\n\nold\n\n## Later\n\nkept\n' >"$repo/docs/plans/2026-01-01-middle.md"
middle_workspace=$(cd "$repo" && bash "$delegate/workspace" "$repo/docs/plans/2026-01-01-middle.md")
printf '# build ledger: plan middle\n' >"$middle_workspace/progress.md"
status write "$repo/docs/plans/2026-01-01-middle.md" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a section followed by another is replaced in place" \
  equals "$(sed -n '/^old$/p;/^## Later$/,$p' "$repo/docs/plans/2026-01-01-middle.md")" $'## Later\n\nkept'

rm "$ledger"
status restore "$plan"
check "execution-status restore: recreates a missing ledger from the copy" \
  equals "$code|$out|$err|$(cat "$ledger")" "0|$ledger|execution-status: recreated the ledger from the plan's Execution status|# build ledger: plan $plan
Task 1 pre-gate: complete (no commits)
Gate do-it: waiting for owner"
status restore "$plan"
check "execution-status restore: a matching ledger stays" \
  equals "$code|$err" "0|execution-status: the ledger matches the plan's Execution status"
printf 'Pause 2026-01-01T10:00:00+0000: resume at Task 1 pre-gate\n' >>"$ledger"
status restore "$plan"
check "execution-status restore: keeps a ledger that extends the copy" \
  equals "$code|$err|$(tail -n 1 "$ledger")" "0|execution-status: kept the ledger, which extends the plan's copy|Pause 2026-01-01T10:00:00+0000: resume at Task 1 pre-gate"
head -n 2 "$ledger" >"$ledger.short" && mv "$ledger.short" "$ledger"
status restore "$plan"
check "execution-status restore: replaces a ledger that the copy extends" \
  equals "$code|$err|$(tail -n 1 "$ledger")" "0|execution-status: replaced the ledger with the plan's longer copy|Gate do-it: waiting for owner"
printf '# build ledger: plan %s\nTask 1: complete (commits a..b, review clean)\n' "$plan" >"$ledger"
status restore "$plan"
check "execution-status restore: a ledger and a copy that disagree exit 1" \
  equals "$code|$(grep -c 'disagree' <<<"$err")" "1|1"
printf '# No fence\n\n## Execution status\n\nold\n' >"$repo/docs/plans/2026-01-01-no-fence.md"
status restore "$repo/docs/plans/2026-01-01-no-fence.md"
check "execution-status restore: a section without a fenced ledger exits 1" \
  equals "$code|$err" "1|execution-status: the Execution status in $repo/docs/plans/2026-01-01-no-fence.md has no fenced ledger"
printf '# Plain\n' >"$repo/docs/plans/2026-01-01-plain.md"
status restore "$repo/docs/plans/2026-01-01-plain.md"
check "execution-status restore: a plan without the section changes nothing" \
  equals "$code|$err" "0|execution-status: $repo/docs/plans/2026-01-01-plain.md has no Execution status; nothing to restore"

cat >"$ledger" <<'EOF'
# build ledger: plan docs/plans/2026-01-01-paused.md
Ruling: keep a\b & "quoted" $HOME 'x' %s `tick`; costs nothing
EOF
cp "$ledger" "$tmp/special-ledger"
status write "$plan" "Task 1 pre-gate (gate do-it)"
rm "$ledger"
status restore "$plan"
check "execution-status: a ledger line with shell, sed and awk specials survives write and restore byte for byte" \
  cmp -s "$ledger" "$tmp/special-ledger"

printf '# No newline\n\nlast' >"$repo/docs/plans/2026-01-01-no-newline.md"
no_newline_workspace=$(cd "$repo" && bash "$delegate/workspace" "$repo/docs/plans/2026-01-01-no-newline.md")
printf '# build ledger: plan no-newline\n' >"$no_newline_workspace/progress.md"
status write "$repo/docs/plans/2026-01-01-no-newline.md" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a plan without a final newline gets the section after a blank line" \
  equals "$code|$(sed -n '3,5p' "$repo/docs/plans/2026-01-01-no-newline.md")" $'0|last\n\n## Execution status'
```

- [ ] **Step 2: Run them to see them fail**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 1, `FAIL:` on all 15 `execution-status` checks (the script does not exist yet), and the last line `build scripts: 15 failure(s)`.

- [ ] **Step 3: Write `execution-status`**

Create `plugins/build/skills/delegate/scripts/execution-status` with exactly this content, then `chmod +x plugins/build/skills/delegate/scripts/execution-status`:

```bash
#!/usr/bin/env bash
# Keep a paused run's ledger on the branch. The ledger lives in the plan's
# workspace under tmp/, which may be emptied at any time and which another
# checkout never has. When a run pauses, `write` copies the ledger verbatim
# into an `## Execution status` section of the plan, which the executor then
# commits; when a run resumes, `restore` brings the workspace's ledger in line
# with that copy.
#
# Usage: execution-status write PLAN_FILE RESUME_AT
#        execution-status restore PLAN_FILE
# write replaces an earlier section in place, or appends one at the end, and
# leaves every other line of the plan as it was. restore recreates a missing
# ledger, replaces a ledger that the copy extends, keeps a ledger that extends
# the copy, and changes nothing when the plan has no section.
# Both print the file they wrote or checked on stdout and a summary on stderr.
# Exit: 1 when restore finds a ledger and a copy that disagree, or a section
# without its fenced copy; 2 on a usage error.
set -euo pipefail

usage() {
  echo "usage: execution-status write PLAN_FILE RESUME_AT | execution-status restore PLAN_FILE" >&2
  exit 2
}

[ $# -ge 2 ] || usage
cmd=$1
plan=$2
case "$cmd" in
  write) [ $# -eq 3 ] || usage ;;
  restore) [ $# -eq 2 ] || usage ;;
  *) usage ;;
esac
[ -f "$plan" ] || {
  echo "no such plan file: $plan" >&2
  exit 2
}

# Invoke via bash rather than direct exec: some plugin installers strip Unix
# exec bits when unpacking.
dir=$("${BASH:-bash}" "$(cd "$(dirname "$0")" && pwd)/workspace" "$plan")
ledger=$dir/progress.md

# The section runs from its heading to the next heading of level two or
# higher outside a code fence. The awk programs below track fences the way
# task-brief does, so a fenced `## Execution status` is text, not a heading.
# shellcheck disable=SC2016  # an awk program, expanded by awk, not the shell
fence_awk='
  function fence() {
    fenceline = 0
    if (match($0, /^[ \t]*(```+|~~~+)/)) {
      run = substr($0, RSTART, RLENGTH)
      sub(/^[ \t]+/, "", run)
      if (!infence) {
        infence = 1
        fch = substr(run, 1, 1)
        flen = length(run)
        fenceline = 1
      } else if (substr(run, 1, 1) == fch && length(run) >= flen && $0 ~ /^[ \t]*[`~]+[ \t]*$/) {
        infence = 0
        fenceline = 1
      }
    }
    return !infence && !fenceline
  }
'

tmp=$(mktemp "$dir/execution-status.XXXXXX")
trap 'rm -f "$tmp"' EXIT

if [ "$cmd" = write ]; then
  resume_at=$3
  [ -f "$ledger" ] || {
    echo "execution-status: no ledger at $ledger" >&2
    exit 2
  }
  if grep -q '^````' "$ledger"; then
    echo "execution-status: the ledger holds a line starting with four backticks, which would end the fence" >&2
    exit 2
  fi
  section=$(mktemp "$dir/execution-status-section.XXXXXX")
  trap 'rm -f "$tmp" "$section"' EXIT
  {
    echo "## Execution status"
    echo
    echo "The run paused here; \`build:finish\` removes this section with the rest of the plan."
    echo "The fence holds the ledger verbatim, and an executor recreates \`progress.md\` from it when its workspace has none."
    echo
    echo "Resume at: $resume_at"
    echo
    echo '````text'
    cat "$ledger"
    echo '````'
  } >"$section"
  awk -v section="$section" "$fence_awk"'
    function emit(   line) {
      while ((getline line < section) > 0) print line
      close(section)
      done = 1
    }
    {
      text = fence()
      if (text && /^#+[ \t]/) {
        level = match($0, /[^#]/) - 1
        if (insec && level <= 2) {
          insec = 0
          print ""
        }
        if (!done && $0 ~ /^##[ \t]+Execution status[ \t]*$/) {
          insec = 1
          emit()
          next
        }
      }
      if (!insec) {
        print
        lastblank = ($0 ~ /^[ \t]*$/)
      }
    }
    END {
      if (!done) {
        if (NR > 0 && !lastblank) print ""
        emit()
      }
    }
  ' "$plan" >"$tmp"
  cat "$tmp" >"$plan"
  printf '%s\n' "$plan"
  echo "execution-status: wrote the Execution status into $plan (resume at: $resume_at)" >&2
  exit 0
fi

# restore: extract the copy, then compare it with the ledger line by line.
rc=0
awk "$fence_awk"'
  {
    text = fence()
    if (text && /^#+[ \t]/) {
      level = match($0, /[^#]/) - 1
      if (insec && level <= 2) insec = 0
      if ($0 ~ /^##[ \t]+Execution status[ \t]*$/) { insec = 1; found = 1 }
      next
    }
    if (!insec) next
    if (!copying && !copied && $0 ~ /^````text[ \t]*$/) { copying = 1; next }
    if (copying && $0 ~ /^````[ \t]*$/) { copying = 0; copied = 1; next }
    if (copying) print
  }
  END {
    if (!found) exit 10
    if (!copied) exit 11
  }
' "$plan" >"$tmp" || rc=$?

case "$rc" in
  0) ;;
  10)
    printf '%s\n' "$ledger"
    echo "execution-status: $plan has no Execution status; nothing to restore" >&2
    exit 0
    ;;
  11)
    echo "execution-status: the Execution status in $plan has no fenced ledger" >&2
    exit 1
    ;;
  *) exit "$rc" ;;
esac

# True when every line of $1 starts $2, in order.
is_prefix() {
  local lines
  lines=$(wc -l <"$1")
  head -n "$((lines))" "$2" | cmp -s - "$1"
}

if [ ! -f "$ledger" ]; then
  cp "$tmp" "$ledger"
  msg="recreated the ledger from the plan's Execution status"
elif cmp -s "$tmp" "$ledger"; then
  msg="the ledger matches the plan's Execution status"
elif is_prefix "$ledger" "$tmp"; then
  cp "$tmp" "$ledger"
  msg="replaced the ledger with the plan's longer copy"
elif is_prefix "$tmp" "$ledger"; then
  msg="kept the ledger, which extends the plan's copy"
else
  echo "execution-status: the ledger at $ledger and the Execution status in $plan disagree; neither extends the other" >&2
  exit 1
fi
printf '%s\n' "$ledger"
echo "execution-status: $msg" >&2
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 0, 54 `ok:` lines and the last line `build scripts: all passed`.

Run: `shellcheck plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/execution-status`
Expected: no output, exit 0.

- [ ] **Step 5: Bump `build` and record the patch**

Set `"version": "0.9.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.9.0 - 2026-09-30

- `delegate` gains `scripts/execution-status`. `write PLAN RESUME_AT` copies the ledger verbatim into an `## Execution status` section of the plan, replacing an earlier one in place and leaving every other line as it was; `restore PLAN` recreates a missing ledger from that copy, replaces a ledger the copy extends, keeps one that extends the copy, and exits 1 when they disagree.
```

At the end of "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`, add:

```markdown
- Added `scripts/execution-status`, which is not upstream: it writes a paused run's ledger into the plan's `## Execution status` section and restores the workspace's ledger from it.
```

- [ ] **Step 6: Commit**

Run: `prek run --files plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/execution-status plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/build/tests/scripts.sh plugins/build/skills/delegate/scripts/execution-status plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): keep a paused run's ledger in the plan"
```

### Task 6: The owner gate protocol and its templates

**Files:**

- Create: `plugins/build/skills/delegate/references/owner-gates.md`
- Create: `plugins/build/skills/delegate/references/evidence-reviewer-prompt.md`
- Modify: `plugins/build/skills/delegate/references/implementer-prompt.md`
- Modify: `plugins/build/skills/delegate/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: `pin` (Task 3), `task-brief --part` (Task 4), `execution-status write|restore` (Task 5), `review-package` (unchanged).
- Produces: `references/owner-gates.md` with the sections "What a gate is", "Who performs the action", "The protocol" (steps 1 to 8), "Unforeseen stops", "Pausing", "Resuming" and "Ledger lines", which the `delegate` and `execute` skill texts link (Tasks 7 and 8).
- Produces: `references/evidence-reviewer-prompt.md` with the placeholders `[MODEL]`, `[PRE_GATE_BRIEF]`, `[POST_GATE_BRIEF]`, `[CONSTRAINT_EMPHASIS]`, `[GATE_LINES]`, `[PINNED_FILES]`, `[STATE_CHANGES]`, `[PRE_GATE_REPORT]`, `[POST_GATE_REPORT]`, `[BASE_SHA]`, `[HEAD_SHA]`, `[DIFF_FILE]`, `[LIVE_ACCESS]`.
- Produces: the implementer template's optional `## Owner Gate` section with the placeholder `[OWNER_GATE]`.

These are documents, so the checks are the hooks and the greps below.

- [ ] **Step 1: Show that none of it exists yet**

Run: `ls plugins/build/skills/delegate/references/; grep -c 'OWNER_GATE' plugins/build/skills/delegate/references/implementer-prompt.md`
Expected: only `implementer-prompt.md`, `re-review-prompt.md` and `task-reviewer-prompt.md` listed, then `0`.

- [ ] **Step 2: Write the protocol**

Create `plugins/build/skills/delegate/references/owner-gates.md` with exactly this content:

````markdown
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

1. **Pre-gate part.** Record BASE, extract the brief with `task-brief PLAN_FILE N --part pre-gate` (`task-start PLAN_FILE N --part pre-gate` in `build:execute`), and run the part: in `build:delegate` a dispatch whose report is `task-N-pre-gate-report.md`, in `build:execute` your own steps.
   Nobody performs the gated action here.
   `task-brief` refuses a malformed gate before anything runs; rule on the plan defect, or stop when every path forward is a guess.
2. **Compare and pin.** Compare every `Expected:` line of the pre-gate steps with the real output; a mismatch is handled as in any task, with a ruling or the fix loop, before the gate.
   Pin what the approval covers with `pin <files>`: the files in `Acts on`, or in `Show` when the gate has no `Acts on`.
   Ledger `Task N pre-gate: complete (no commits; pins <file> sha256:<hex>, ...)` with every hash whole.
   A command with no file inputs is pinned by its text: ledger it in backticks in place of a file.
3. **Decide whether to ask.** A gate passes without asking only when its index row holds a pre-approval, `Performed by` names the agent, every pre-gate `Expected:` line matched, no ruling changed a step of the task, and no instruction of the repository requires the owner's approval of this action at run time.
   Then ledger `Gate <id>: pre-approved (plan index); Expected lines matched` and go to step 5.
   When a pre-approval exists but a condition fails, ledger `Gate <id>: pre-approval void (<the condition that failed>); asking`; an instruction of the repository that the plan did not mark wins over the pre-approval.
4. **Ask.** Send the gate message, ledger `Gate <id>: waiting for owner`, and wait:

   ```text
   Owner gate <id> (Task N)
   Consequences: <verbatim from the plan>
   Artifact: <path>, sha256 <first 12 hex digits>
   <the Ask, verbatim>
   On no: <verbatim from the plan>
   Answer yes, no with what to change, or later.
   ```

   Quote the artifact verbatim when it has at most 40 lines; otherwise quote the pre-gate `Expected:` lines and link the file.
   At a gate the owner performs, give the exact commands or instructions in place of the artifact, and ask for "done" once they have run, with the output when the owner has it.
   Only an explicit yes, or "done" at a gate the owner performs, passes the gate.
   Ledger the answer verbatim, with the time from `date +%Y-%m-%dT%H:%M:%S%z`: `Gate <id>: owner <time>: "<answer>"`.
   A no follows the gate's `On no`; "later" pauses the run (see [Pausing](#pausing)).
5. **Post-gate part.** Extract the brief with `task-brief PLAN_FILE N --part post-gate`, and ledger `Task N post-gate: dispatched` (`started` in `build:execute`).
   In `build:delegate`, dispatch a fresh implementer, never the pre-gate one resumed, because the gate may have spanned sessions; its report is `task-N-post-gate-report.md`, and the template's `[OWNER_GATE]` block carries the approval: the answer verbatim or the pre-approval, every pin, and the exact commands approved.
   Before anything else the part checks every pin with `pin --check sha256:<hex> <file>`, and for an action that depends on live state it re-runs the dry run and compares the output byte for byte with the approved one.
   A mismatch stops it without acting: the approval is void, and the gate goes back to step 1.
   An action that fails partway (one of several applies fails) stops the part, which acts no further, as the plan's steps say; the failure becomes an unforeseen gate that shows the error.
6. **Record commit.** The post-gate part ends with a record commit, empty (`git commit --allow-empty`) when the repository did not change.
   Its message body is the evidence: the gate ID, the owner's answer verbatim with its time or the pre-approval, the pins, the commands run in order with their result lines, and the results of the checks.
   It holds summaries and identifiers, never a secret.
7. **Evidence review.** Generate `review-package PLAN_FILE BASE HEAD` and dispatch the reviewer in [evidence-reviewer-prompt.md](evidence-reviewer-prompt.md) with both briefs, both reports, the pinned files, this gate's ledger lines, the `State:` lines and read-only access to the live system.
   A fix that needs another live action is an unforeseen gate.
8. **Complete.** In `build:delegate`, ledger `Task N: complete (commits <base7>..<head7>, evidence review clean)`, or `(commits <base7>..<head7>, <K> parked)` after a tripped breaker.
   In `build:execute`, `task-done` records the completion once the evidence review is clean.

## Unforeseen stops

A stop the plan did not declare (an implementer reports BLOCKED on an ungated apply, the plan is broken beyond guessing, a check could only be passed by weakening it) runs the same protocol:

- Its ID is `unplanned-<slug>`.
- Its `Show` is `gate-<id>.md`, which you write in the workspace: what you met, the options and what each costs, and the path of any artifact the part produced.
- The task splits where it stopped: the steps already done are its pre-gate part, keeping their report, and the rest runs after the answer as a post-gate part that carries the answer.
- It can never be pre-approved.
- Ledger the answer as a gate line and as `State: owner answered <id>: "<answer>"`, so every later reviewer judges against it.

A final-review finding whose fix needs a live change gets such a gate in the fix wave.

## Pausing

A run pauses on "later" at a gate, when the owner ends the session, or when you are about to end with a gate unanswered.
In this order:

1. Remove the task's pre-gate artifacts, the files its Files block lists as temporary, so a stale one can never be acted on.
   After an owner's "done", remove nothing: the action has happened, and the run resumes at the post-gate part.
2. Append `Pause <time>: resume at Task N pre-gate; removed <files>` to the ledger, or `resume at Task N post-gate` after "done".
3. Run `execution-status write PLAN_FILE "Task N pre-gate (gate <id>)"`, or `post-gate` after "done".
   It copies the ledger verbatim into an `## Execution status` section at the end of the plan, replacing an earlier one.
4. Commit the plan alone: `git commit -m "docs(plan): pause at gate <id>" -- PLAN_FILE`.
   Do not push; give the owner the push command in case they want a backup.
5. End with a prompt the owner can paste to resume: the executor's skill and the plan path.

## Resuming

At setup, a plan that ends with an `## Execution status` section is a paused run: run `execution-status restore PLAN_FILE` before reading the ledger.
It recreates a missing ledger from the copy, replaces a ledger that the copy extends, keeps a ledger that extends the copy, and exits 1 when they disagree, which is an unforeseen stop.
Ledger `Resume <time>: <what it printed>`.

Then, for the task at a gate:

- A run-time approval lapses at a pause: re-run the pre-gate part and ask again, even when the new artifact is identical.
- A pre-approval does not lapse; step 3 checks it again.
- An owner's "done" does not lapse: resume at the post-gate part, which verifies.
- A `Task N post-gate: dispatched` (or `started`) line with no completion after it means the part may already have acted: never re-run it blindly; make it an unforeseen gate that shows its report.

The section stays in the plan until the next pause rewrites it or `build:finish` removes the plan.

## Ledger lines

```text
Task 6 pre-gate: complete (no commits; pins bootstrap.tfplan sha256:<64 hex digits>)
Gate apply-state-bucket: waiting for owner
Gate apply-state-bucket: owner 2026-09-27T14:51:55+0800: "Go ahead and apply!"
Gate apply-state-bucket: pre-approved (plan index); Expected lines matched
Gate apply-state-bucket: pre-approval void (Step 3 expected 6 to add, got 7 to add); asking
Task 6 post-gate: dispatched
Pause 2026-09-27T14:11:02+0800: resume at Task 6 pre-gate; removed backend_override.tf, bootstrap.tfplan
Resume 2026-09-27T14:39:40+0800: recreated the ledger from the plan's Execution status
Task 6: complete (commits 6033d2e..a1b2c3d, evidence review clean)
```

`Task 6 pre-gate:` never matches the resume check for `Task 6: complete`, so a finished pre-gate part never reads as a finished task.
````

- [ ] **Step 3: Write the evidence reviewer template**

Create `plugins/build/skills/delegate/references/evidence-reviewer-prompt.md` with exactly this content:

````markdown
# Evidence reviewer prompt template

Use this template to review a task that passed an owner gate.
Its change lies partly or wholly outside the repository, so the reviewer reads the evidence and the live system, not only a diff, and returns two verdicts: spec compliance and quality.

**Purpose:** verify that the action matched the approval and nothing else ran, that the live system is in the state the task requires, and that the record commit tells the truth.

```text
Dispatch a subagent with:
  description: "Evidence review of Task N"
  model: [MODEL, required: choose per the Model selection section of SKILL.md;
         an omitted model silently inherits the session's most expensive one]
  prompt: |
    You are reviewing one task that passed an owner gate: the owner
    approved or performed an action on a live system, and the task
    verified it and recorded it in a commit. This is a task-scoped gate,
    not a merge review; a broad whole-branch review happens separately
    after all tasks are complete.

    ## What Was Requested

    Read both briefs: [PRE_GATE_BRIEF] and [POST_GATE_BRIEF].
    The gate block in them names what the owner saw (Show), what the
    approval pins (Acts on), who performed the action, and what it
    changes. Their Global Constraints section, when present, binds this
    task as much as the task text does. [CONSTRAINT_EMPHASIS]

    ## What the Owner Approved

    [GATE_LINES]

    These are the ledger's lines for this gate: the pins recorded before
    it, and the owner's answer verbatim with its time, or the
    pre-approval. The pinned files are: [PINNED_FILES]
    They are your baseline: the action must match them, and nothing
    beyond them may have happened.

    ## State Changes Since the Inputs Were Written

    [STATE_CHANGES]

    These facts superseded the plan, the spec or an inventory they cite
    after those were written. Where an input and this list disagree, the
    list is current: judge the work against it.

    ## What the Implementers Claim

    Read both reports: [PRE_GATE_REPORT] and [POST_GATE_REPORT].
    If one holds several dated attempts, the last one is current.

    ## Commits Under Review

    **Base:** [BASE_SHA]
    **Head:** [HEAD_SHA]
    **Package file:** [DIFF_FILE]

    Read the package once. It holds every commit with its full message,
    the record commit included, whose body is the task's evidence; the
    record commit may be empty. Do not re-run git commands. If the package
    file is missing, fetch the range yourself:
    `git log [BASE_SHA]..[HEAD_SHA]` and `git diff [BASE_SHA]..[HEAD_SHA]`.

    ## The Live System

    [LIVE_ACCESS]

    Query the live system with read-only calls only: calls that
    describe, list, get or plan without taking effect. Never run a call
    that creates, changes, deletes, locks or unlocks anything, and never
    run the gated action or any command from the briefs that takes effect.
    If a check you need would take effect, report it as a ⚠️ item instead.
    Make one focused call per named check, and name the check and the call
    in your report. Your review is read-only on this checkout too: do not
    mutate the working tree, the index, HEAD, or branch state.

    ## You Do Not Dispatch Subagents

    Do all of this review yourself. Never spawn a subagent to review part
    of the evidence, and never spawn another reviewer for a second
    opinion. This process already provides every review seat the work
    gets; a reviewer you spawn duplicates one of them at full cost, and
    its verdict counts for nothing.

    ## Do Not Trust the Reports

    Treat both reports and the record commit's message as unverified
    claims. Verify them against the pins, the package and the live
    system. Rationales in a report are the implementer grading their own
    work; judge on the merits, and a stated rationale never downgrades a
    finding's severity.

    ## Checks

    The implementer ran the task's checks and reported their output. Do
    not re-run them. Read every check the task wrote or ran: could it pass
    when the property it names does not hold, or fail when it does? A
    check the task never showed failing without its property is a
    finding.

    ## Part 1: Spec Compliance

    - **Approval matched:** the action that ran is the approved one. The
      pins were checked before it, the commands are the approved commands,
      and for an action that depends on live state the dry run was re-run
      and matched. Anything done beyond the approval is Critical.
    - **Live state:** the live system is in the state the task's Produces
      block and checks describe; verify it with read-only calls.
    - **Record commit:** its message holds the gate ID, the answer or the
      pre-approval, the pins, the commands in order with their results and
      the results of the checks; it matches the reports; it holds no
      secret.
    - **Missing, extra, misunderstood:** steps skipped or claimed without
      evidence, anything done beyond the briefs, a step done the wrong way.

    If a requirement cannot be verified from the evidence and read-only
    calls, report it as a ⚠️ item.

    ## Part 2: Quality

    The checks and scripts the task wrote: does each assertion test its
    property, and does a failure fail loudly? The live resources: anything
    that departs from the design. The repository changes in the package:
    judge them as a code review would.

    Point at evidence: file:line for files, and the call and its output
    for live findings. Your final message is the report itself: begin
    directly with the spec-compliance verdict. Every line is a verdict, a
    finding with evidence, or a check you ran; no preamble, no closing
    summary.

    ## Calibration

    Categorize issues by actual severity. An action beyond the approval,
    or a live state that contradicts the task, is Critical. Important
    means this task cannot be trusted until it is fixed. "Coverage could
    be broader" and polish are Minor. If the plan or brief mandates
    something this rubric calls a defect, report it as Important, labeled
    plan-mandated; the user decides. Acknowledge what was done well before
    listing issues.

    ## Output Format

    ### Spec Compliance

    - ✅ Spec compliant | ❌ Issues found: [with evidence]
    - ⚠️ Cannot verify: [what, and what the controller should check]

    ### Live Checks

    [each read-only call you ran, and what it showed]

    ### Strengths

    ### Issues

    #### Critical (Must Fix)
    #### Important (Should Fix)
    #### Minor (Nice to Have)

    ### Assessment

    **Task quality:** [Approved | Needs fixes]

    **Reasoning:** [1-2 sentence technical assessment]
```

## Placeholders

- `[MODEL]`: required, at least a mid-tier model, and the most capable when the action was destructive.
- `[PRE_GATE_BRIEF]`, `[POST_GATE_BRIEF]`: required, the two briefs `task-brief --part` wrote.
- `[CONSTRAINT_EMPHASIS]` (optional): one sentence naming the global constraint this task is most likely to break.
- `[GATE_LINES]`: required, the ledger's lines for this gate, verbatim: the pre-gate line with its pins, and the answer or pre-approval line.
- `[PINNED_FILES]`: required, the paths of the pinned files, or "none" for a gate pinned by command text alone.
- `[STATE_CHANGES]` (optional): the ledger's `State:` lines.
- `[PRE_GATE_REPORT]`, `[POST_GATE_REPORT]`: required, the two report files.
- `[BASE_SHA]`, `[HEAD_SHA]`: the commit before the task and the current commit.
- `[DIFF_FILE]`: required, the path `review-package PLAN_FILE BASE HEAD` printed.
- `[LIVE_ACCESS]`: required, how to reach the live system read-only (the tool, the profile or context, the calls the briefs' checks use), or "none" when the action changed nothing outside the repository.

Leave out the emphasis sentence and the "State Changes Since the Inputs Were Written" section when there is nothing to fill them with.

**The reviewer returns:** the spec compliance verdict (✅, ❌ or ⚠️), the live checks it ran, strengths, issues (Critical, Important, Minor) and the task quality verdict.
````

- [ ] **Step 4: Teach the implementer template about gates and record commits**

In `plugins/build/skills/delegate/references/implementer-prompt.md`, make these three replacements.

Replace

```text
    4. Commit as the brief specifies; by default, one commit per task on
       the current branch, Conventional Commits, one concern per commit,
       never on main. A brief may declare that the task commits nothing;
       then commit nothing, and say so in your report
```

with

```text
    4. Commit as the brief specifies; by default, one commit per task on
       the current branch, Conventional Commits, one concern per commit,
       never on main. Every task ends with at least one commit: a task
       whose work lies outside the repository ends with a record commit
       (empty, with `git commit --allow-empty`, when nothing in the
       repository changed) whose message body holds the evidence the
       brief names. The pre-gate part of an owner gate commits nothing
```

Replace

```text
    [Scene-setting: where this fits, dependencies, architectural context]

    ## Before You Begin
```

with

```text
    [Scene-setting: where this fits, dependencies, architectural context]

    ## Owner Gate

    [OWNER_GATE]

    ## Before You Begin
```

Replace

```text
    - Commits created (short SHA + subject), or "none" when the brief
      declares that the task commits nothing
```

with

```text
    - Commits created (short SHA + subject), or "none" for the pre-gate
      part of an owner gate
```

Then, in the "Placeholders" list after the fenced template, add after the `[BRIEF_FILE]` item:

```markdown
- `[OWNER_GATE]` (only for a task with an owner gate; leave out the whole `## Owner Gate` section otherwise): for the pre-gate part, "Your brief ends at an owner gate, and you run only the steps before it. Never perform the gated action, nor anything its `Performed by` line names; commit nothing; leave every file the gate shows or acts on in place, because the controller shows them to the owner. When the steps before the gate are done, report DONE." For the post-gate part of a gate the agent performs, "The owner has approved this gate, and the approval covers exactly this: <the answer verbatim with its time, or `pre-approved in the plan's Owner Gates index`>; pins: <each file with its full sha256>; commands: <the exact commands approved>. Before anything else, check every pin with `bash <build:delegate's scripts directory>/pin --check sha256:<hex> <file>`; for an action whose effect depends on live state, re-run the dry run the brief names and compare its output byte for byte with the approved one. On any mismatch, stop without acting and report BLOCKED with both values. Then run the steps after the gate, and end with the record commit the brief describes." For the post-gate part of a gate the owner performed, "The owner performed this gate's action and answered: <the answer verbatim with its time>. Never perform it again. Run the steps after the gate, which verify the result, and end with the record commit the brief describes."
```

- [ ] **Step 5: Show that the documents are in place**

Run: `ls plugins/build/skills/delegate/references/; grep -c 'OWNER_GATE' plugins/build/skills/delegate/references/implementer-prompt.md; grep -c 'commits nothing;' plugins/build/skills/delegate/references/implementer-prompt.md`
Expected: `evidence-reviewer-prompt.md`, `implementer-prompt.md`, `owner-gates.md`, `re-review-prompt.md` and `task-reviewer-prompt.md` listed, then `2` (the section and the placeholder item), then `0`.

- [ ] **Step 6: Bump `build` and record the patch**

Set `"version": "0.10.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.10.0 - 2026-09-30

- `delegate` gains `references/owner-gates.md`, the protocol both executors follow at an owner gate: the two parts of a gated task, who may perform the action, the pins, the pre-approval check, the gate message, the record commit, unforeseen stops, pausing and resuming, and the ledger lines. `references/evidence-reviewer-prompt.md` reviews a gated task against the approved artifact, the record commit and the live system through read-only calls. The implementer template ends every task with at least one commit, a record commit for work outside the repository, instead of letting a brief declare that a task commits nothing, and carries an optional `## Owner Gate` section for the two parts.
```

At the end of "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`, add:

```markdown
- Added `references/owner-gates.md` and `references/evidence-reviewer-prompt.md`, which are not upstream. Implementer template: every task ends with at least one commit, a task whose work lies outside the repository with a record commit (empty when nothing changed), replacing "a brief may declare that the task commits nothing"; an optional `## Owner Gate` section (`[OWNER_GATE]`) tells a pre-gate implementer to stop at the gate, and a post-gate implementer what the approval covers and to check the pins first.
```

- [ ] **Step 7: Commit**

Run: `prek run --files plugins/build/skills/delegate/references/owner-gates.md plugins/build/skills/delegate/references/evidence-reviewer-prompt.md plugins/build/skills/delegate/references/implementer-prompt.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`, `validate prerequisites` included.

```bash
git add plugins/build/skills/delegate/references/owner-gates.md plugins/build/skills/delegate/references/evidence-reviewer-prompt.md plugins/build/skills/delegate/references/implementer-prompt.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): write the owner gate protocol and its review template"
```

### Task 7: `build:delegate` follows the protocol

**Files:**

- Modify: `plugins/build/skills/delegate/SKILL.md`
- Modify: `plugins/build/skills/delegate/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: `references/owner-gates.md` and `references/evidence-reviewer-prompt.md` (Task 6), `scripts/execution-status` (Task 5), `task-brief --part` (Task 4).
- Produces: the section heading `## Owner gates` in `delegate/SKILL.md`, which the `execute` skill text does not link (it links `owner-gates.md` directly).

Make each replacement below exactly; the old text is quoted from the current file.

- [ ] **Step 1: Show the current state**

Run: `grep -c 'owner-gates.md\|Owner gate' plugins/build/skills/delegate/SKILL.md`
Expected: `0`.

- [ ] **Step 2: Continuous execution and the stops**

Replace

```markdown
They review at two gates only: the plan before execution, and the pull request afterwards.
Execute all tasks from the plan without stopping.
The only reasons to stop are the five named below, or all tasks complete.
```

with

```markdown
They review planned work at two review gates: the plan before execution, and the pull request afterwards.
Between them they decide only at owner gates: the ones the plan declares, and the five stops below.
Execute all tasks from the plan without stopping anywhere else.
```

Replace

```markdown
For those, stop and ask.
Never disable, skip or weaken a check or hook to make something pass, and never let an implementer do so.
```

with

```markdown
For those, stop and ask, through the protocol in [Owner gates](#owner-gates): the plan may have declared the stop as an owner gate, which the owner may have pre-approved by its ID, and a stop it did not declare is an unforeseen gate.
Never disable, skip or weaken a check or hook to make something pass, and never let an implementer do so.
```

- [ ] **Step 3: The process graph**

In the `digraph process` block, after the line

```text
        "Append completion to ledger, mark todo complete" [shape=box];
```

add

```text
        "Task has an owner gate?" [shape=diamond];
        "Owner gate protocol (references/owner-gates.md): pre-gate dispatch, gate, post-gate dispatch, record commit" [shape=box];
        "Dispatch evidence reviewer (references/evidence-reviewer-prompt.md)" [shape=box];
```

Replace the edge

```text
    "Setup: worktree, ledger check, read plan, pre-flight review" -> "Dispatch implementer subagent (references/implementer-prompt.md)";
```

with

```text
    "Setup: worktree, ledger check, read plan, pre-flight review" -> "Task has an owner gate?";
    "Task has an owner gate?" -> "Dispatch implementer subagent (references/implementer-prompt.md)" [label="no"];
    "Task has an owner gate?" -> "Owner gate protocol (references/owner-gates.md): pre-gate dispatch, gate, post-gate dispatch, record commit" [label="yes"];
    "Owner gate protocol (references/owner-gates.md): pre-gate dispatch, gate, post-gate dispatch, record commit" -> "Dispatch evidence reviewer (references/evidence-reviewer-prompt.md)";
    "Dispatch evidence reviewer (references/evidence-reviewer-prompt.md)" -> "Spec ✅ and quality approved?";
```

Replace the edge

```text
    "More tasks remain?" -> "Dispatch implementer subagent (references/implementer-prompt.md)" [label="yes"];
```

with

```text
    "More tasks remain?" -> "Task has an owner gate?" [label="yes"];
```

- [ ] **Step 4: Setup restores a paused run**

In "Workspace and ledger", after the bullet that begins ``- Check for this plan's ledger at `<workspace>/progress.md`.`` (it ends with "leave it in place and start your own, fresh."), add:

```markdown
- A plan that ends with an `## Execution status` section is a run that paused: before you read the ledger, run `scripts/execution-status restore PLAN_FILE` as [owner-gates.md](references/owner-gates.md) says under Resuming.
  A task with a `Task <N> pre-gate:` line and no completion line is at its gate; resume it as that section says.
```

Replace

```markdown
- `git clean -fdx` will destroy the workspace (it is git-ignored scratch), and `tmp/` may be emptied at any time; if that happens, recover from `git log`.
```

with

```markdown
- `git clean -fdx` will destroy the workspace (it is git-ignored scratch), and `tmp/` may be emptied at any time; if that happens, recover from the plan's Execution status when it has one, and from `git log` otherwise.
```

- [ ] **Step 5: Model selection and the task brief**

In "Model selection", after the paragraph that begins `**Review tasks:**` (it ends with "Scoped re-reviews of small fix diffs take a cheap-to-mid tier."), add:

```markdown
**Evidence reviews** of tasks with an owner gate: at least a mid-tier model, and the most capable one when the action was destructive; a wrong verdict leaves an unverified change on a live system.
```

In "1. Dispatch the implementer", at the end of the `**Task brief.**` bullet (after "Never make a subagent read the whole plan file."), add on its own line, indented as the bullet's other lines:

```markdown
  A task with an owner gate gets two briefs, one per part, as [Owner gates](#owner-gates) says.
```

- [ ] **Step 6: The Owner gates section**

Insert this section between the end of "### 5. Complete the task" and `## Final review`:

```markdown
## Owner gates

A task with an owner gate (a step `` - [ ] **Step N: Owner gate `<id>`** ``) runs in two dispatches around the gate, and you take the gate itself: an implementer cannot ask the owner anything.
Read [owner-gates.md](references/owner-gates.md) before the first gated task and follow it step by step: the pre-gate dispatch, pinning, the pre-approval check, the gate message, the fresh post-gate dispatch that carries the approval in the implementer template's `[OWNER_GATE]` block, the record commit, the evidence review with [evidence-reviewer-prompt.md](references/evidence-reviewer-prompt.md), pausing and resuming.
Each of the five stops above that the plan did not declare runs the same protocol as an unforeseen gate.
The evidence review takes the place of the task review for a gated task; its findings go through the fix loop like any other.
```

- [ ] **Step 7: The final review and the final message**

In "Final review", after the first paragraph (it ends with "instead of re-deriving the branch diff with git commands."), add:

```markdown
The final review stays after the last task, gated or not; the record commits of the gated tasks are in its package.
A finding whose fix needs a live change gets an unforeseen owner gate in the fix wave.
```

In "Finish", replace

```markdown
Collect every ledger line containing `Ruling:` (pre-flight rulings, parked findings, breaker adjudications, all of them) into your final message under "Rulings I made", in the order you made them, each with what it costs if wrong, and every `minor (deferred)` line under "Deferred minors".
Both lists are exhaustive: if the ledger holds a ruling, the list holds it.
```

with

```markdown
Collect every ledger line containing `Ruling:` (pre-flight rulings, parked findings, breaker adjudications, all of them) into your final message under "Rulings I made", in the order you made them, each with what it costs if wrong, every `minor (deferred)` line under "Deferred minors", and every `Gate` line under "Owner gates", each with the record commit of its task.
All three lists are exhaustive: if the ledger holds a ruling, the list holds it.
```

- [ ] **Step 8: Rationalizations and the example**

Add these rows at the end of the "Common rationalizations" table:

```markdown
| "The owner will obviously say yes, I'll run the apply now" | Only an explicit yes passes a gate, or a pre-approval the plan's index records by the gate's ID. |
| "The artifact is identical to the one approved before the pause" | A run-time approval lapses at a pause. Re-run the pre-gate part and ask again. |
| "The task changed nothing in the repository, so there is nothing to commit" | A gated task ends with its record commit, empty if need be; the evidence lives in its message. |
| "Resume the pre-gate implementer for the post-gate part" | The post-gate part is a fresh dispatch that carries the approval; the gate may have spanned sessions. |
```

In "Example workflow", insert this block between the line `...` and the line `[After all tasks]`, with one blank line on each side:

```text
Task 3: Apply the saved plan (owner gate apply-bucket)

[Run task-brief PLAN_FILE 3 --part pre-gate; dispatch implementer with the pre-gate brief and the [OWNER_GATE] stop text]
Implementer: plan saved, 6 to add; show output in bucket.plan.txt; no commits
[Pre-gate Expected lines match; pin bucket.tfplan]
[Ledger: Task 3 pre-gate: complete (no commits; pins bucket.tfplan sha256:5891b5b5...)]
[Index: apply-bucket is not pre-approved; send the gate message]
[Ledger: Gate apply-bucket: waiting for owner]

User: "Yes."

[Ledger: Gate apply-bucket: owner 2026-09-23T14:02:11+0800: "Yes."]
[Run task-brief PLAN_FILE 3 --part post-gate; ledger: Task 3 post-gate: dispatched]
[Dispatch a fresh implementer with the approval in [OWNER_GATE]]
Implementer: pin matches; apply: 6 added; checks 9 PASS; empty record commit e1f2a3b with the evidence
[Run review-package PLAN_FILE BASE HEAD; dispatch the evidence reviewer]
Evidence reviewer: approval matched; live state verified; record commit accurate. Approved.
[Ledger: Task 3: complete (commits b7c8d9e..e1f2a3b, evidence review clean)]
```

and, after the example's `Deferred minors:` list (`- (none)`), add:

```text

Owner gates:
- apply-bucket: "Yes." (2026-09-23T14:02:11+0800), record commit e1f2a3b
```

- [ ] **Step 9: Show the new state**

Run: `grep -c 'owner-gates.md' plugins/build/skills/delegate/SKILL.md; grep -c '^## Owner gates$' plugins/build/skills/delegate/SKILL.md; grep -c 'The only reasons to stop are the five named below' plugins/build/skills/delegate/SKILL.md`
Expected: `5` (the graph's node line, its two edge lines that name the node, the setup bullet and the section's paragraph), then `1`, then `0`.

- [ ] **Step 10: Bump `build` and record the patch**

Set `"version": "0.11.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.11.0 - 2026-09-30

- `delegate` runs a task with an owner gate as `references/owner-gates.md` says: two dispatches around the gate, which the controller takes; a pre-approved gate passes without asking; the post-gate dispatch is fresh and carries the approval; an evidence review takes the place of the diff review. Each of the five stops that the plan did not declare runs the same protocol as an unforeseen gate. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates next to the rulings and deferred minors.
```

At the end of "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`, add:

```markdown
- Owner gates, which are not upstream: continuous execution names the review gates and the owner gates; the five stops run the protocol in `references/owner-gates.md`, as unforeseen gates when the plan did not declare them; the process graph branches on a gated task; setup restores a paused run's ledger with `scripts/execution-status restore`; evidence reviews get a model floor; the final review stays after the last task; the final message lists the owner gates; four rationalization rows and a gated task in the example workflow.
```

- [ ] **Step 11: Commit**

Run: `prek run --files plugins/build/skills/delegate/SKILL.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`, `validate prerequisites` included.

```bash
git add plugins/build/skills/delegate/SKILL.md plugins/build/skills/delegate/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): run owner gates in build:delegate"
```

### Task 8: `build:execute` follows the protocol

**Files:**

- Modify: `plugins/build/skills/execute/scripts/task-start` (replaced whole)
- Modify: `plugins/build/tests/scripts.sh` (a `task-start` section)
- Modify: `plugins/build/skills/execute/SKILL.md`
- Modify: `plugins/build/skills/execute/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: `task-brief --part` (Task 4), the test helper `fixture` (Task 4), `owner-gates.md` and `evidence-reviewer-prompt.md` (Task 6), `execution-status` (Task 5).
- Produces: `task-start PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate]`, which passes `--part` to `task-brief` and prints `brief: <path>` and `base: <sha>`; exit 2 when the third argument is anything but `--part`.

- [ ] **Step 1: Add the `task-start` tests**

In `plugins/build/tests/scripts.sh`, insert this section immediately before the line `# --- Summary ---...`:

```bash
# --- task-start --------------------------------------------------------------

execute=$build/skills/execute/scripts
repo=$(new_repo task-start)
plan=$repo/docs/plans/2026-01-01-fixture.md
fixture >"$plan"
start() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$execute/task-start" "$@"
}

start "$plan" 2 --part pre-gate
check "task-start: passes --part to task-brief" \
  equals "$code|$(sed -n 's/^brief: .*\///p' <<<"$out")" "0|task-2-pre-gate-brief.md"
check "task-start: prints BASE" \
  equals "$(sed -n 's/^base: //p' <<<"$out")" "$(git -C "$repo" rev-parse HEAD)"
start "$plan" 2
check "task-start: a gated task without --part fails as task-brief does" \
  equals "$code" "3"
start "$plan" 2 --bogus pre-gate
check "task-start: anything but --part as the third argument is a usage error" \
  equals "$code" "2"
```

- [ ] **Step 2: Run them to see them fail**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 1; `FAIL:` on `task-start: passes --part to task-brief` and `task-start: prints BASE` (the current script rejects four arguments); `ok:` on the other two, which already hold; the last line `build scripts: 2 failure(s)`.

- [ ] **Step 3: Replace `task-start`**

Replace the whole of `plugins/build/skills/execute/scripts/task-start` with exactly this content, keeping its exec bit:

```bash
#!/usr/bin/env bash
# Begin one task of an inline plan execution in a single call: extract the
# task's brief with the plan's Global Constraints (via the delegate skill's
# task-brief, so both executors share one workspace) and record BASE, the
# commit the task's review range is cut from. One tool call instead of two,
# because every call in an inline session is a turn that re-reads the whole
# context. For a task with an owner gate, --part names the part to begin, as
# task-brief takes it.
#
# Usage: task-start PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate]
# Prints:
#   brief: <path to the task's brief file>
#   base:  <full SHA of HEAD>
set -euo pipefail

if { [ $# -ne 2 ] && [ $# -ne 4 ]; } || { [ $# -eq 4 ] && [ "$3" != "--part" ]; }; then
  echo "usage: task-start PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate]" >&2
  exit 2
fi

plan=$1
n=$2
shift 2
delegate="$(cd "$(dirname "$0")/../../delegate/scripts" && pwd)"

# Invoke via bash rather than direct exec: some plugin installers strip Unix
# exec bits when unpacking.
brief=$("${BASH:-bash}" "$delegate/task-brief" "$plan" "$n" "$@")

echo "brief: $brief"
echo "base: $(git rev-parse HEAD)"
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `plugins/build/tests/scripts.sh`
Expected: exit 0, 58 `ok:` lines and the last line `build scripts: all passed`.

Run: `shellcheck plugins/build/tests/scripts.sh plugins/build/skills/execute/scripts/task-start`
Expected: no output, exit 0.

- [ ] **Step 5: Continuous execution and the stops**

In `plugins/build/skills/execute/SKILL.md`, replace

```markdown
They review at two gates only: the plan before execution, and the pull request afterwards.
They chose inline execution to spend less, not to answer "should I continue?" after every task.
Execute all tasks from the plan without stopping.
```

with

```markdown
They review planned work at two review gates: the plan before execution, and the pull request afterwards.
Between them they decide only at owner gates: the ones the plan declares, and the five stops below.
They chose inline execution to spend less, not to answer "should I continue?" after every task.
Execute all tasks from the plan without stopping anywhere else.
```

Replace

```markdown
For those, stop and ask.
Never disable, skip or weaken a check or hook to make something pass.
```

with

```markdown
For those, stop and ask, through the protocol in [Owner gates](#owner-gates): the plan may have declared the stop as an owner gate, which the owner may have pre-approved by its ID, and a stop it did not declare is an unforeseen gate.
Never disable, skip or weaken a check or hook to make something pass.
```

- [ ] **Step 6: The process graph**

In the `digraph process` block, after the line

```text
        "task-done: run tests, ledger the result; mark todo complete" [shape=box];
```

add

```text
        "Task has an owner gate?" [shape=diamond];
        "Owner gate protocol (../delegate/references/owner-gates.md): pre-gate steps, gate, post-gate steps, record commit, evidence review" [shape=box];
```

Replace the edge

```text
    "Setup: worktree, workspace + ledger, read plan + design, pre-flight scan" -> "task-start: brief + BASE; read the brief";
```

with

```text
    "Setup: worktree, workspace + ledger, read plan + design, pre-flight scan" -> "Task has an owner gate?";
    "Task has an owner gate?" -> "task-start: brief + BASE; read the brief" [label="no"];
    "Task has an owner gate?" -> "Owner gate protocol (../delegate/references/owner-gates.md): pre-gate steps, gate, post-gate steps, record commit, evidence review" [label="yes"];
    "Owner gate protocol (../delegate/references/owner-gates.md): pre-gate steps, gate, post-gate steps, record commit, evidence review" -> "task-done: run tests, ledger the result; mark todo complete";
```

Replace the edge

```text
    "More tasks remain?" -> "task-start: brief + BASE; read the brief" [label="yes"];
```

with

```text
    "More tasks remain?" -> "Task has an owner gate?" [label="yes"];
```

- [ ] **Step 7: Setup, the task start and the Owner gates section**

In "Workspace and ledger", after the bullet that begins ``- Check for this plan's ledger at `<workspace>/progress.md`.`` (it ends with "leave it and start your own, fresh."), add:

```markdown
- A plan that ends with an `## Execution status` section is a run that paused: before you read the ledger, run `../delegate/scripts/execution-status restore PLAN_FILE` from this skill's directory, as [owner-gates.md](../delegate/references/owner-gates.md) says under Resuming.
  A task with a `Task <N> pre-gate:` line and no completion line is at its gate; resume it as that section says.
```

Replace

```markdown
- `git clean -fdx` will destroy the workspace (it is git-ignored scratch), and `tmp/` may be emptied at any time; if that happens, recover from `git log`.
```

with

```markdown
- `git clean -fdx` will destroy the workspace (it is git-ignored scratch), and `tmp/` may be emptied at any time; if that happens, recover from the plan's Execution status when it has one, and from `git log` otherwise.
```

In "1. Take the task", replace

```markdown
- Run this skill's `scripts/task-start PLAN_FILE N`.
```

with

```markdown
- Run this skill's `scripts/task-start PLAN_FILE N`; a task with an owner gate starts each part with `--part`, as [Owner gates](#owner-gates) says.
```

Insert this section between the end of "### 4. Complete the task" and `## Final review`:

```markdown
## Owner gates

A task with an owner gate (a step `` - [ ] **Step N: Owner gate `<id>`** ``) runs in two parts around the gate.
Read [owner-gates.md](../delegate/references/owner-gates.md) before the first gated task and follow it step by step, with these differences:

- Each part starts with `scripts/task-start PLAN_FILE N --part pre-gate` or `--part post-gate`, and you run its steps yourself.
  In the pre-gate part you never perform the gated action; its brief ends at the gate with "Stop here".
- Ledger `Task N post-gate: started` where the protocol says `dispatched`.
- The evidence review is a subagent dispatch here too, with [evidence-reviewer-prompt.md](../delegate/references/evidence-reviewer-prompt.md) on at least a mid-tier model, because the final review reads a diff and cannot see live state.
  Fix its Critical and Important findings in one pass, each verified by a test or a re-run check that failed first, and ledger `Task N: evidence review clean` or `Task N: evidence review: <K> fixed`.
  Without a subagent tool, apply the template yourself as a separate pass and ledger `Task N: evidence review: self-review (no subagent tool)`.
- Then run `task-done` with the task's checks as its test command; it records the completion line.
```

- [ ] **Step 8: The final review, the final message and the rationalizations**

In "Final review", after the first paragraph (it ends with "and review from the file it prints."), add:

```markdown
The final review stays after the last task, gated or not; the record commits of the gated tasks are in its package.
A finding whose fix needs a live change gets an unforeseen owner gate in the fix pass.
```

In "Finish", replace

```markdown
Collect every ledger line containing `Ruling:` into your final message under "Rulings I made", in the order you made them, each with what it costs if wrong, and every `minor (deferred)` line under "Deferred minors".
Both lists are exhaustive.
```

with

```markdown
Collect every ledger line containing `Ruling:` into your final message under "Rulings I made", in the order you made them, each with what it costs if wrong, every `minor (deferred)` line under "Deferred minors", and every `Gate` line under "Owner gates", each with the record commit of its task.
All three lists are exhaustive.
```

Add these rows at the end of the "Common rationalizations" table:

```markdown
| "The owner will obviously say yes, I'll run the apply now" | Only an explicit yes passes a gate, or a pre-approval the plan's index records by the gate's ID. |
| "The artifact is identical to the one approved before the pause" | A run-time approval lapses at a pause. Re-run the pre-gate part and ask again. |
| "I checked the live state myself, the evidence review is redundant" | Same author, same blind spots, and the final review cannot see live state. Dispatch the evidence reviewer. |
```

- [ ] **Step 9: Show the new state**

Run: `grep -c '^## Owner gates$' plugins/build/skills/execute/SKILL.md; grep -c 'owner-gates.md' plugins/build/skills/execute/SKILL.md; grep -c 'They review at two gates only' plugins/build/skills/execute/SKILL.md`
Expected: `1`, then `5` (the graph's node line, its two edge lines that name the node, the setup bullet and the section's paragraph), then `0`.

- [ ] **Step 10: Bump `build` and record the patch**

Set `"version": "0.12.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.12.0 - 2026-09-30

- `execute` runs a task with an owner gate as `delegate`'s `references/owner-gates.md` says, doing both parts itself and dispatching the evidence reviewer, since its final review cannot see live state. `task-start` takes `--part pre-gate|post-gate` and passes it to `task-brief`. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates.
```

At the end of "Local patches" in `plugins/build/skills/execute/UPSTREAM.md`, add:

```markdown
- Owner gates, which are not upstream: continuous execution names the review gates and the owner gates; the five stops run the protocol in `../delegate/references/owner-gates.md`; the process graph branches on a gated task; `task-start` passes `--part pre-gate|post-gate` to `task-brief`; setup restores a paused run's ledger; an `## Owner gates` section says how the inline executor differs (it runs both parts, dispatches the evidence reviewer, and records the completion with `task-done`); the final message lists the owner gates; three rationalization rows.
```

- [ ] **Step 11: Commit**

Run: `prek run --files plugins/build/tests/scripts.sh plugins/build/skills/execute/scripts/task-start plugins/build/skills/execute/SKILL.md plugins/build/skills/execute/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`, `validate prerequisites` included.

```bash
git add plugins/build/tests/scripts.sh plugins/build/skills/execute/scripts/task-start plugins/build/skills/execute/SKILL.md plugins/build/skills/execute/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): run owner gates in build:execute"
```

### Task 9: `build:plan` writes gates, the index and the pre-approvals

**Files:**

- Modify: `plugins/build/skills/plan/SKILL.md`
- Modify: `plugins/build/skills/plan/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: the gate format `task-brief` parses (Task 4) and the protocol in `owner-gates.md` (Task 6).
- Produces: plans with a `### Owner Gates` index as the first subsection of `## Plan`, gate steps in the format of the Global Constraints, and pre-approvals recorded in the index.

- [ ] **Step 1: Show the current state**

Run: `grep -c 'Owner gate\|Owner Gates' plugins/build/skills/plan/SKILL.md`
Expected: `0`.

- [ ] **Step 2: The index in the plan header**

In the fenced "Plan section header" template of `plugins/build/skills/plan/SKILL.md`, between the `**Spec:**` line and `### Global Constraints`, insert (with one blank line before and after):

```markdown
### Owner Gates

[One row per owner gate in the plan (see Owner gates below), or the single line "None." when the plan has none:

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-state-bucket` | 6 | agent | creates the state bucket; versions kept forever | no |

Pre-approved says "no" until the user pre-approves the gate at the handoff, and then holds their reply verbatim with its time; a gate that an instruction of the repository keeps from pre-approval says "not pre-approvable (<the instruction>)".]
```

- [ ] **Step 3: The Owner gates section**

Replace

```markdown
A task may span several commits when the plan says so.
Never `git commit` on main.
```

with

```markdown
A task may span several commits when the plan says so.
Every task ends with at least one commit; a task whose work lies outside the repository ends with a record commit, as a task with an owner gate does.
Never `git commit` on main.
```

Then insert this section between the end of "Task structure" (the line "Never `git commit` on main." that the replacement above kept) and `## Checks and commands`:

````markdown
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
````

- [ ] **Step 4: No placeholders and self-review**

At the end of the "No placeholders" list, add:

```markdown
- A gate missing a required field, or an owner action anywhere but at a gate inside a task
```

After self-review item 6 (it ends with "so a contradiction the plan carries ships."), add:

```markdown
7. **Owner gates.** Every task that performs a stop-list action (an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree) has a gate, and no step before a gate performs one.
   Every gate has all its fields, and the index has exactly one row per gate, or "None." when there is none.
   Every gate the agent performs has an action its approval pins, and every dry run a post-gate step compares is deterministic.
   The step that produces a pre-approvable gate's artifact has an exact `Expected:` line, and every gate that an instruction of the repository keeps from pre-approval is marked, with the instruction named.
```

- [ ] **Step 5: The handoff asks for pre-approvals**

Replace

```markdown
Between the two the executor asks them nothing: it rules on conflicts, records its rulings in a ledger, and presents them in the pull request description.
```

with

```markdown
Between the two the executor asks them nothing except at owner gates: it rules on conflicts, records its rulings in a ledger, and presents them in the pull request description.
```

In the first handoff template, replace

```text
are, what a shipped mistake would cost]. You will not be asked again until
the branch is finished. Does the plan capture what you want, and which
approach should we use?
```

with

```text
are, what a shipped mistake would cost]. You will not be asked again until
the branch is finished, except at the owner gates you do not pre-approve.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does the plan capture what you want, and which approach should we use?
```

In the second handoff template, replace

```text
Plan complete and committed as docs/plans/<filename>.md. Please review it.
Does it capture what you want?
```

with

```text
Plan complete and committed as docs/plans/<filename>.md. Please review it.
[Only when the plan has owner gates that can be pre-approved:]
These owner gates can be pre-approved, so the executor passes them without
stopping; approving the plan pre-approves none of them:
- <ID>: <Consequences>
Which of them, if any, do you pre-approve?
Does it capture what you want?
```

Before the line that begins "If delegation is chosen,", add:

```markdown
Write each pre-approval the user gives into the index's Pre-approved column: their reply, verbatim, with the time from `date +%Y-%m-%dT%H:%M:%S%z`.
A reply that approves the plan without naming a gate pre-approves none, and a gate marked not pre-approvable stays so whatever the reply says.
Commit the index as `docs(plan): record pre-approved owner gates` before invoking the executor.
```

- [ ] **Step 6: Show the new state**

Run: `grep -c '^## Owner gates$' plugins/build/skills/plan/SKILL.md; grep -c '^### Owner Gates$' plugins/build/skills/plan/SKILL.md; grep -c 'record pre-approved owner gates' plugins/build/skills/plan/SKILL.md`
Expected: `1`, `1`, `1`.

- [ ] **Step 7: Bump `build` and record the patch**

Set `"version": "0.13.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.13.0 - 2026-09-30

- `plan` writes owner gates: a gate step with its ID and fields in the task that performs a hard-to-reverse action, the rules for the steps before and after it and for who may perform the action, and a `### Owner Gates` index as the first subsection of the plan. Every task ends with at least one commit. The handoff lists the gates that can be pre-approved and asks which, by ID; the answer goes into the index, committed as `docs(plan): record pre-approved owner gates`. Self-review checks the gates.
```

At the end of "Local patches" in `plugins/build/skills/plan/UPSTREAM.md`, add:

```markdown
- Owner gates, which are not upstream: a `### Owner Gates` index in the plan header; an `## Owner gates` section with the gate step, its fields and its rules; every task ends with at least one commit; a "No placeholders" item and self-review item 7 for gates; the handoff asks for pre-approvals by ID and records them in the index before invoking the executor.
```

- [ ] **Step 8: Commit**

Run: `prek run --files plugins/build/skills/plan/SKILL.md plugins/build/skills/plan/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`, `validate prerequisites` included.

```bash
git add plugins/build/skills/plan/SKILL.md plugins/build/skills/plan/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): write owner gates and pre-approvals in build:plan"
```

### Task 10: `build:finish` restores a paused ledger and reports the gates

**Files:**

- Modify: `plugins/build/skills/finish/SKILL.md`
- Modify: `plugins/build/skills/finish/UPSTREAM.md`, `plugins/build/CHANGELOG.md`, `plugins/build/.claude-plugin/plugin.json`

**Interfaces:**

- Consumes: `execution-status restore` (Task 5); the ledger's `Gate` lines (Task 6).
- Produces: an "Owner gates" list in the pull request description.

- [ ] **Step 1: Show the current state**

Run: `grep -c 'Execution status\|Owner gates' plugins/build/skills/finish/SKILL.md`
Expected: `0`.

- [ ] **Step 2: Step 2 restores a paused run's ledger**

In `plugins/build/skills/finish/SKILL.md`, replace

```markdown
Without a `progress.md`, no executor produced the branch and there is no ledger.
```

with

````markdown
When it has no `progress.md` but the plan ends with an `## Execution status` section, a paused run left its ledger in the plan: recreate it before the plan goes, with `bash <this skill's directory>/../delegate/scripts/execution-status restore docs/plans/YYYY-MM-DD-<slug>.md`.
Without either, no executor produced the branch and there is no ledger.
Collect the ledger's owner gates for the description (Step 5):

```bash
grep -E '^Gate ' "$PLAN_WORKSPACE/progress.md"
```
````

- [ ] **Step 3: The description lists the owner gates**

In Step 5, replace

```markdown
4. Review findings nobody fixed.
5. Verification: the full check command and its result, and any other evidence by name.
```

with

```markdown
4. When the ledger has owner gates, an "Owner gates" list: each gate's ID, the owner's answer verbatim with its time or the pre-approval, and the record commit that ends its task.
5. Review findings nobody fixed.
6. Verification: the full check command and its result, and any other evidence by name.
```

Add this row at the end of the "Common rationalizations" table:

```markdown
| "The workspace is gone, so the ledger is lost" | A paused run left a copy in the plan's Execution status. Restore it before the plan is removed. |
```

- [ ] **Step 4: Show the new state**

Run: `grep -c 'execution-status restore' plugins/build/skills/finish/SKILL.md; grep -c 'Owner gates' plugins/build/skills/finish/SKILL.md`
Expected: `1`, `1`.

- [ ] **Step 5: Bump `build` and record the patch**

Set `"version": "0.14.0"` in `plugins/build/.claude-plugin/plugin.json`.
At the top of `plugins/build/CHANGELOG.md`, add:

```markdown
## 0.14.0 - 2026-09-30

- `finish` recreates a paused run's ledger from the plan's Execution status before it removes the plan, and the pull request description lists the owner gates: each gate's ID, the answer or the pre-approval, and the record commit of its task.
```

At the end of "Local patches" in `plugins/build/skills/finish/UPSTREAM.md`, add:

```markdown
- Owner gates, which are not upstream: Step 2 recreates a paused run's ledger from the plan's `## Execution status` with `../delegate/scripts/execution-status restore` and collects the ledger's `Gate` lines; the description gains an "Owner gates" list; one rationalization row.
```

- [ ] **Step 6: Commit**

Run: `prek run --files plugins/build/skills/finish/SKILL.md plugins/build/skills/finish/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/build/skills/finish/SKILL.md plugins/build/skills/finish/UPSTREAM.md plugins/build/CHANGELOG.md plugins/build/.claude-plugin/plugin.json
git commit -m "feat(build): restore a paused ledger and list owner gates in build:finish"
```

### Task 11: The workflow and the standing instructions name owner gates

**Files:**

- Modify: `shared/WORKFLOW.md` (symlinked into `build:plan` and `discover:approach`)
- Modify: `plugins/conventions/skills/engineering/SKILL.md`
- Modify: `plugins/build/README.md`
- Modify: `plugins/build/.claude-plugin/plugin.json`, `plugins/build/CHANGELOG.md`, `plugins/discover/.claude-plugin/plugin.json`, `plugins/discover/CHANGELOG.md`, `plugins/conventions/.claude-plugin/plugin.json`, `plugins/conventions/CHANGELOG.md`

**Interfaces:**

- Consumes: the terms review gate, owner gate and pre-approval in `CONCEPTS.md`.
- Produces: nothing later tasks read.

- [ ] **Step 1: Show the current state**

Run: `grep -c 'owner gate\|Review gate' shared/WORKFLOW.md; grep -c 'pre-approved' plugins/conventions/skills/engineering/SKILL.md`
Expected: `0`, then `0`.

- [ ] **Step 2: The flows**

In `shared/WORKFLOW.md`, make these replacements:

- `2. **Gate**: the user says yes to that design.` becomes `2. **Review gate**: the user says yes to that design.`
- `6. **Gate**: the user reviews the pull request and merges it or asks for changes.` becomes `6. **Review gate**: the user reviews the pull request and merges it or asks for changes.`
- `3. **Gate 1**: the user reviews the design and the plan, and picks the executor.` becomes `3. **Review gate 1**: the user reviews the design and the plan, picks the executor, and pre-approves by ID the owner gates they want passed without a stop.`
- In step 4 of the architectural change, `builds it, one commit per task, without asking.` becomes `builds it, one commit per task, without asking, and stops only at owner gates.`
- `6. **Gate 2**: the user reviews the pull request,` becomes `6. **Review gate 2**: the user reviews the pull request,`.

- [ ] **Step 3: Who decides what**

Replace

```markdown
The user decides at the gates: the classification (they can override it), the design, the plan and the executor, and whether the pull request merges.
Between the gates the executor decides: conflicts inside the plan, ambiguities, findings it parks, all recorded as rulings in the ledger and surfaced in the pull request.
Four things always stop an executor for the user: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish), and a plan so broken that every path forward is a guess.
```

with

```markdown
The user decides at the review gates: the classification (they can override it), the design, the plan and the executor, and whether the pull request merges.
Between the review gates the executor decides: conflicts inside the plan, ambiguities, findings it parks, all recorded as rulings in the ledger and surfaced in the pull request.
The user also decides at owner gates, where the executor stops until they approve or perform a hard-to-reverse action, or answer a question the executor must not settle alone.
A plan declares the owner gates it foresees, and the user may pre-approve each one by its ID when approving the plan; approving the plan pre-approves none of them.
Four things stop an executor for the user, unless the plan declares them as a gate the user pre-approved: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish), and a plan so broken that every path forward is a guess.
```

After the line `A fifth is Lyngon's: a check or hook is never disabled, skipped or weakened to get past it.`, add:

```markdown
Every stop, planned or not, runs the same protocol: the executor shows what the user must see, asks one question and records the answer; when the session ends before the answer, it pauses with a copy of its ledger in the plan, so a later session resumes it.
```

Replace

```markdown
Between the gates, the executor is also the reviewer's client: a task reviewer after every task in `/build:delegate`, a whole-branch reviewer at the end in both executors.
```

with

```markdown
Between the review gates, the executor is also the reviewer's client: a task reviewer after every task in `/build:delegate`, an evidence reviewer after every task with an owner gate in both executors, and a whole-branch reviewer at the end in both.
```

- [ ] **Step 4: What gets written where**

Replace

```markdown
- The design and the plan in `docs/plans/YYYY-MM-DD-<slug>.md`, committed on the branch and removed by `/build:finish`.
- The execution ledger, briefs and review packages in `tmp/build/<slug>/`, scratch that never enters git.
```

with

```markdown
- The design and the plan in `docs/plans/YYYY-MM-DD-<slug>.md`, with the index of owner gates and the user's pre-approvals, committed on the branch and removed by `/build:finish`.
- The execution ledger, briefs and review packages in `tmp/build/<slug>/`, scratch that enters git only as the verbatim copy of the ledger in the plan's `## Execution status` section when a run pauses, removed with the plan.
- The evidence of every owner gate in the record commit that ends its task, empty when the repository did not change.
```

- [ ] **Step 5: The standing instructions and the build README**

In `plugins/conventions/skills/engineering/SKILL.md`, replace

```markdown
- Ask before any other effect outside the branch: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish.
```

with

```markdown
- Ask before any other effect outside the branch: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish. An owner gate that a plan declares and the user pre-approved by its ID counts as asking.
```

In `plugins/build/README.md`, replace

```markdown
The user reviews at two gates: the plan before execution, and the pull request afterwards, starting from the executor's "Rulings I made" and "Deferred minors" lists in its description.
Between the gates the executor commits per task on a feature branch and does not stop to ask, except for the stop conditions every executor carries.
The execution ledger and the task briefs live under `tmp/build/<plan>/`, the agent scratch directory, never in git.
See [ADR 0016](../../docs/adr/0016-planned-work-is-reviewed-at-two-gates.md).
```

with

```markdown
The user reviews at two review gates: the plan before execution, and the pull request afterwards, starting from the executor's "Rulings I made", "Deferred minors" and "Owner gates" lists in its description.
Between them the executor commits per task on a feature branch and stops only at owner gates: the ones the plan declares, each of which the user may pre-approve by its ID when approving the plan, and the stop conditions every executor carries.
Every task with an owner gate ends with a record commit that holds its evidence.
The execution ledger and the task briefs live under `tmp/build/<plan>/`, the agent scratch directory; when a run pauses at a gate, the ledger is copied into the plan, so a later session resumes it.
See [ADR 0016](../../docs/adr/0016-planned-work-is-reviewed-at-two-gates.md) and [ADR 0018](../../docs/adr/0018-owner-gates-are-declared-in-the-plan-and-pre-approved-by-name.md).
```

- [ ] **Step 6: Show the new state**

Run: `grep -c '\*\*Gate' shared/WORKFLOW.md; grep -c 'owner gate' shared/WORKFLOW.md; grep -c 'pre-approved by its ID counts as asking' plugins/conventions/skills/engineering/SKILL.md`
Expected: `0`, then at least `5`, then `1`.

- [ ] **Step 7: Bump the three plugins**

Set `"version": "0.15.0"` in `plugins/build/.claude-plugin/plugin.json`, `"version": "0.6.0"` in `plugins/discover/.claude-plugin/plugin.json` and `"version": "0.11.0"` in `plugins/conventions/.claude-plugin/plugin.json`.
At the top of each changelog, add:

`plugins/build/CHANGELOG.md`:

```markdown
## 0.15.0 - 2026-09-30

- `WORKFLOW.md`, symlinked into `plan`, names the review gates and the owner gates: the user pre-approves owner gates by ID at the first review gate, the executors stop only at owner gates, every stop runs the same protocol, and the Execution status and the record commits are listed with what gets written where. The README says so.
```

`plugins/discover/CHANGELOG.md`:

```markdown
## 0.6.0 - 2026-09-30

- `WORKFLOW.md`, symlinked into `approach`, names the review gates and the owner gates, pre-approval by ID, the protocol every stop runs, the Execution status and the record commits.
```

`plugins/conventions/CHANGELOG.md`:

```markdown
## 0.11.0 - 2026-09-30

- `engineering` counts an owner gate that a plan declares and the user pre-approved by its ID as asking before an effect outside the branch.
```

- [ ] **Step 8: Commit**

Run: `prek run --files shared/WORKFLOW.md plugins/conventions/skills/engineering/SKILL.md plugins/build/README.md plugins/build/.claude-plugin/plugin.json plugins/build/CHANGELOG.md plugins/discover/.claude-plugin/plugin.json plugins/discover/CHANGELOG.md plugins/conventions/.claude-plugin/plugin.json plugins/conventions/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`, `validate prerequisites` and `validate marketplace` included.

```bash
git add shared/WORKFLOW.md plugins/conventions/skills/engineering/SKILL.md plugins/build/README.md plugins/build/.claude-plugin/plugin.json plugins/build/CHANGELOG.md plugins/discover/.claude-plugin/plugin.json plugins/discover/CHANGELOG.md plugins/conventions/.claude-plugin/plugin.json plugins/conventions/CHANGELOG.md
git commit -m "feat(build,discover,conventions): name owner gates in the workflow and the standing instructions"
```

### Task 12: Rehearse owner gates end to end

**Files:**

- Create, scratch only: `tmp/rehearsal/` (a throwaway repository, a stand-in live directory, a helper script, prompts and run outputs; `tmp/` is gitignored)
- Commit: an empty record commit with the rehearsal's evidence, or one fix commit per defect found and then the record commit

**Interfaces:**

- Consumes: every earlier task; the rehearsal loads this worktree's `build`, `practice` and `review` plugins.
- Produces: the evidence that the protocol works across a pre-approved gate, an asked gate, a pause, a lost workspace and a resume.

The protocol lives in skill text that no script can run, so a nested headless session executes a two-task plan with `build:execute`, the cheaper executor, which runs both parts itself and still dispatches the evidence reviewer.
Use the most capable model for this task's implementer: it judges whether the nested runs followed the protocol.
If the environment refuses to start a nested session (sign-in, a permission prompt, a refusal), stop and report BLOCKED with the output.
If a nested run departs from the protocol, find the sentence of skill text that let it, fix it in the file that owns it as a patch bump of that plugin (`build` 0.15.1 and so on) with its changelog entry and upstream note, one commit per defect, and run the rehearsal again from Step 1.

- [ ] **Step 1: Set up the throwaway repository and the live directory**

Run each command from the worktree root:

```bash
rm -rf tmp/rehearsal && mkdir -p tmp/rehearsal/live tmp/rehearsal/repo/docs/plans
git -C tmp/rehearsal/repo init -q -b main
printf '/tmp/\n' > tmp/rehearsal/repo/.gitignore
git -C tmp/rehearsal/repo add .gitignore
git -C tmp/rehearsal/repo commit -q -m "chore: start"
git -C tmp/rehearsal/repo switch -q -c feat/rehearsal
```

Create `tmp/rehearsal/repo/docs/plans/2026-09-30-rehearsal.md` with exactly this content:

```markdown
# Rehearsal of owner gates

## Design

### Goal

Rehearse the build plugin's owner gates in a throwaway repository: one gate pre-approved, one asked at run time, a pause, and a resume in a new session.
The directory `../live/` next to this repository stands in for a live system; nothing else outside the repository is touched.

### Out of scope

Everything else.

## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` (recommended) or `build:execute` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Copy two stamps into the stand-in live directory, each through an owner gate.

**Architecture:** Each task writes its stamp in the repository's `tmp/`, which the gate shows, and copies it to `../live/` after the gate.

**Tech stack:** POSIX shell.

**Spec:** The `## Design` section of this file.

### Owner Gates

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `write-target-one` | 1 | agent | writes `../live/target-1.txt` | 2026-09-30T12:00:00+0800: "I pre-approve write-target-one." |
| `write-target-two` | 2 | agent | writes `../live/target-2.txt` | no |

### Global Constraints

- The stand-in live system is `../live/`; nothing else outside the repository is touched.

### Review Focus

None: the rehearsal has no inputs beyond its two stamps.

### Task 1: Stamp target one

**Files:**

- Temporary: `tmp/stamp-1.txt`

**Interfaces:**

- Consumes: nothing.
- Produces: `../live/target-1.txt`, holding `stamp one`.

- [ ] **Step 1: Write the stamp**

Run: `mkdir -p tmp && printf 'stamp one\n' > tmp/stamp-1.txt && cat tmp/stamp-1.txt`
Expected: `stamp one`

- [ ] **Step 2: Owner gate `write-target-one`**
  - Show: `tmp/stamp-1.txt`
  - Ask: "Copy tmp/stamp-1.txt to ../live/target-1.txt?"
  - Performed by: agent, `cp tmp/stamp-1.txt ../live/target-1.txt`
  - Consequences: writes `../live/target-1.txt` in the stand-in live directory; `rm ../live/target-1.txt` undoes it
  - On no: record the reason and stop the task

- [ ] **Step 3: Copy the stamp**

Run: `cp tmp/stamp-1.txt ../live/target-1.txt && cat ../live/target-1.txt`
Expected: `stamp one`

- [ ] **Step 4: Record commit**

Run: `rm tmp/stamp-1.txt`, then commit an empty record commit with the subject `chore: record the stamp of target one` and the evidence in its body.
Expected: `git log -1 --format=%s` prints `chore: record the stamp of target one`.

### Task 2: Stamp target two

**Files:**

- Temporary: `tmp/stamp-2.txt`

**Interfaces:**

- Consumes: nothing.
- Produces: `../live/target-2.txt`, holding `stamp two`.

- [ ] **Step 1: Write the stamp**

Run: `mkdir -p tmp && printf 'stamp two\n' > tmp/stamp-2.txt && cat tmp/stamp-2.txt`
Expected: `stamp two`

- [ ] **Step 2: Owner gate `write-target-two`**
  - Show: `tmp/stamp-2.txt`
  - Ask: "Copy tmp/stamp-2.txt to ../live/target-2.txt?"
  - Performed by: agent, `cp tmp/stamp-2.txt ../live/target-2.txt`
  - Consequences: writes `../live/target-2.txt` in the stand-in live directory; `rm ../live/target-2.txt` undoes it
  - On no: record the reason and stop the task

- [ ] **Step 3: Copy the stamp**

Run: `cp tmp/stamp-2.txt ../live/target-2.txt && cat ../live/target-2.txt`
Expected: `stamp two`

- [ ] **Step 4: Record commit**

Run: `rm tmp/stamp-2.txt`, then commit an empty record commit with the subject `chore: record the stamp of target two` and the evidence in its body.
Expected: `git log -1 --format=%s` prints `chore: record the stamp of target two`.
```

Then commit it in the throwaway repository:

```bash
git -C tmp/rehearsal/repo add docs/plans/2026-09-30-rehearsal.md
git -C tmp/rehearsal/repo commit -q -m "docs: add the rehearsal plan"
```

- [ ] **Step 2: Write the helper and the prompts**

Create `tmp/rehearsal/claude-run.sh` with this content and `chmod +x` it:

```bash
#!/usr/bin/env bash
# Rehearsal helper: run one headless session in the throwaway repository with
# this worktree's build, practice and review plugins and no user settings, so
# no installed copy of the plugins loads. Prints the session id.
# Usage: claude-run.sh OUTPUT_JSON PROMPT_FILE [--resume SESSION_ID]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
worktree=$(cd "$here/../.." && pwd)
out=$1
prompt=$2
shift 2
cd "$here/repo"
env -i HOME="$HOME" PATH="$PATH" TERM=dumb claude -p "$(cat "$prompt")" "$@" \
  --model sonnet \
  --setting-sources project \
  --strict-mcp-config \
  --plugin-dir "$worktree/plugins/build" \
  --plugin-dir "$worktree/plugins/practice" \
  --plugin-dir "$worktree/plugins/review" \
  --allowedTools "Bash Read Write Edit Glob Grep Skill Agent" \
  --output-format json >"$out" </dev/null
jq -r '.session_id' "$out"
```

Create these four prompt files:

- `tmp/rehearsal/prompt-start.txt`: `This is a rehearsal of the build plugin's owner gates in a throwaway repository, run by the plugin's maintainers to check that the skills work; the directory ../live/ next to this repository stands in for a live system. Execute docs/plans/2026-09-30-rehearsal.md with the build:execute skill, in this checkout without a worktree, on the current branch feat/rehearsal. After the final whole-branch review, stop instead of invoking build:finish. When an owner gate asks, send its gate message and end your turn; I answer in the next message.`
- `tmp/rehearsal/prompt-resume.txt`: `This is the same rehearsal of the build plugin's owner gates, in a new session; the directory ../live/ next to this repository stands in for a live system. Resume docs/plans/2026-09-30-rehearsal.md with the build:execute skill, in this checkout without a worktree, on the current branch feat/rehearsal. After the final whole-branch review, stop instead of invoking build:finish. When an owner gate asks, send its gate message and end your turn; I answer in the next message.`
- `tmp/rehearsal/prompt-later.txt`: `later`
- `tmp/rehearsal/prompt-yes.txt`: `Yes.`

- [ ] **Step 3: Run the first session: a pre-approved gate and an asked gate**

Before the run, show that its checks fail:
Run: `cat tmp/rehearsal/live/target-1.txt; ls tmp/rehearsal/repo/tmp/build/2026-09-30-rehearsal/progress.md`
Expected: both report `No such file or directory`.

Run: `tmp/rehearsal/claude-run.sh tmp/rehearsal/run-1.json tmp/rehearsal/prompt-start.txt`
Expected: a session id on stdout; keep it as SESSION_1.

Set `L=tmp/rehearsal/repo/tmp/build/2026-09-30-rehearsal/progress.md` in each command below, and check:

- `cat tmp/rehearsal/live/target-1.txt` prints `stamp one`, and `ls tmp/rehearsal/live` lists only `target-1.txt`.
- `grep -c '^Gate write-target-one: pre-approved (plan index); Expected lines matched$' "$L"` prints `1`.
- `grep -c '^Task 1: evidence review' "$L"` prints `1`, and `grep -c '^Task 1: complete' "$L"` prints `1`.
- `git -C tmp/rehearsal/repo log --format=%B | grep -c 'write-target-one'` prints at least `1` (the record commit's evidence).
- `grep -c '^Gate write-target-two: waiting for owner$' "$L"` prints `1`.
- `jq -r .result tmp/rehearsal/run-1.json | grep -c 'Owner gate write-target-two'` prints `1`.

- [ ] **Step 4: Answer "later" and check the pause**

Before the answer, show that its checks fail:
Run: `grep -c '^## Execution status$' tmp/rehearsal/repo/docs/plans/2026-09-30-rehearsal.md`
Expected: `0`.

Run: `tmp/rehearsal/claude-run.sh tmp/rehearsal/run-2.json tmp/rehearsal/prompt-later.txt --resume SESSION_1`

Check:

- `grep -c '^## Execution status$' tmp/rehearsal/repo/docs/plans/2026-09-30-rehearsal.md` prints `1`.
- `git -C tmp/rehearsal/repo log -1 --format=%s` prints `docs(plan): pause at gate write-target-two`.
- `ls tmp/rehearsal/repo/tmp/stamp-2.txt` reports `No such file or directory`, and `ls tmp/rehearsal/live` still lists only `target-1.txt`.
- `grep -c '^Pause .*resume at Task 2 pre-gate' tmp/rehearsal/repo/tmp/build/2026-09-30-rehearsal/progress.md` prints `1`.

- [ ] **Step 5: Lose the workspace and resume in a new session**

Run: `rm -rf tmp/rehearsal/repo/tmp/build; ls tmp/rehearsal/repo/tmp/build/2026-09-30-rehearsal/progress.md`
Expected: `No such file or directory`, so the checks below can only pass if the session recreates the ledger.

Run: `tmp/rehearsal/claude-run.sh tmp/rehearsal/run-3.json tmp/rehearsal/prompt-resume.txt`
Expected: a session id; keep it as SESSION_3.

Check, with `L` as above:

- `grep -c 'recreated the ledger' "$L"` prints `1` (the `Resume` line).
- `grep -c '^Gate write-target-two: waiting for owner$' "$L"` prints `2` (once in the copy, once when asked again).
- `jq -r .result tmp/rehearsal/run-3.json | grep -c 'Owner gate write-target-two'` prints `1`.
- `ls tmp/rehearsal/live` still lists only `target-1.txt`.

- [ ] **Step 6: Answer yes and check the finish**

Before the answer, show that its checks fail:
Run: `cat tmp/rehearsal/live/target-2.txt`
Expected: `No such file or directory`.

Run: `tmp/rehearsal/claude-run.sh tmp/rehearsal/run-4.json tmp/rehearsal/prompt-yes.txt --resume SESSION_3`

Check, with `L` as above:

- `cat tmp/rehearsal/live/target-2.txt` prints `stamp two`.
- `grep -c '^Gate write-target-two: owner .*: "Yes\."$' "$L"` prints `1`.
- `grep -c '^Task 2: evidence review' "$L"` prints `1`, and `grep -c '^Task [12]: complete' "$L"` prints `2`.
- `git -C tmp/rehearsal/repo log --format=%s | grep -c '^chore: record the stamp of target'` prints `2`, and both record commits are empty: `git -C tmp/rehearsal/repo log --format=%H --grep='^chore: record the stamp' | while read -r c; do git -C tmp/rehearsal/repo diff --quiet "$c^" "$c" && echo empty; done` prints `empty` twice.
- `jq -r .result tmp/rehearsal/run-4.json | grep -c 'Owner gates'` prints at least `1` (the final message's list).

- [ ] **Step 7: Commit the evidence**

Write a record commit in this repository; it is empty, because the rehearsal changed nothing here (or, when defects were fixed, it follows their fix commits).
Its body lists, one line each: the `claude --version` output and the nested model; each run's session id and the checks of its step with their results; and the defects found and the commits that fixed them, or "none".

```bash
git commit --allow-empty -F tmp/rehearsal/commit-message.txt
```

with `tmp/rehearsal/commit-message.txt` starting with the subject line `test(build): rehearse owner gates end to end`, a blank line, and the body.
Expected: `git log -1 --format=%s` prints `test(build): rehearse owner gates end to end`, and the `commitizen` and prose hooks pass at commit time.

### Task 13: Remove the landed seed prompt

**Files:**

- Delete: `docs/seed-prompts/owner-gates.md`
- Modify: `docs/TODO.md` (the queued owner gates entry)
- Modify: `docs/seed-prompts/roadmap-for-multi-piece-work.md` (decision 5 names the removed file)

**Interfaces:**

- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Show the references**

Run: `grep -rn 'seed-prompts/owner-gates.md' docs`
Expected: two lines, `docs/TODO.md:9` and `docs/seed-prompts/roadmap-for-multi-piece-work.md:27`.

- [ ] **Step 2: Remove the entry and the prompt, and repoint the roadmap prompt**

Delete the line in `docs/TODO.md` that begins `- 2026-09-27: [Owner gates and operational tasks](seed-prompts/owner-gates.md)`.
Run: `git rm -q docs/seed-prompts/owner-gates.md`
In `docs/seed-prompts/roadmap-for-multi-piece-work.md`, replace

```markdown
5. Its relation to the pause record of `docs/seed-prompts/owner-gates.md`, so the two do not become two files for one purpose.
```

with

```markdown
5. Its relation to the `## Execution status` section a paused run writes into its plan (ADR 0018), so the two do not become two files for one purpose.
```

- [ ] **Step 3: Show that nothing points at it**

Run: `grep -rn 'seed-prompts/owner-gates.md' docs; prek run --files docs/TODO.md docs/seed-prompts/roadmap-for-multi-piece-work.md`
Expected: no `grep` output, then every hook `Passed` or `Skipped`.

- [ ] **Step 4: Commit**

```bash
git add docs/TODO.md docs/seed-prompts/roadmap-for-multi-piece-work.md
git commit -m "docs: remove the landed owner gates seed prompt"
```
