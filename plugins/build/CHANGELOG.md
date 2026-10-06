# Changelog

All notable changes to the `build` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.16.0 - 2026-10-06

- A fix to protocol text gets a state walk before it is made.
  Protocol text names states and the events that move between them, or states a rule that holds across steps, and is recognized by a sentence that is read on more than one path (a fresh and a resumed run, a first attempt and a retry, an action the agent or the owner performs); a value, a command or a step's wording that is read on one path gets no walk.
  In the delegate skill's fix loop and final fix wave, the controller writes a walk list of the states and paths that read the sentence, each with the outcome it must give, checks any wording it dictates against each entry, and sends the list with the findings.
  The re-review template has an optional "The State Walk" section (`[WALK_LIST]`): the re-reviewer verdicts each entry HOLDS or BROKEN, reads the whole of the files the fix touched for it, and a BROKEN state joins the open findings; such a re-review takes at least a mid-tier model.
  In the execute skill's fix pass after the final review, the executor lists the states before the edit, reads the fixed text in each after it, and ledgers the walk as `Final: walked <finding>; ...`.
  Three dictated fixes to the owner gate protocol each introduced a new Important finding that only the next review cycle found.

## 0.15.50 - 2026-10-04

- The finish skill's commands run in a session that its harness isolates in a worktree: each is a plain command with its values written out, where Steps 2, 3, 6 and 7 captured output in shell variables and wrapped git in command substitution, which Claude Code refuses there as "too complex to verify that it stays inside the worktree".
  The plan workspace, the merge base, the git directories, the worktree path and the main repository root are read from what a command printed and written into the next one.
  Step 6 says that such a session hands a local merge, a discard and the cleanup of Step 7 to the user, because the harness refuses git in the main repository.

## 0.15.49 - 2026-09-30

- Fix rounds after a gate the owner performed get their own `[OWNER_GATE]` text in the implementer template, which opens with the owner's action and answer and never asks for the pins or the dry run, and the delegate skill and its owner gates reference send the fix-round text whether the agent or the owner performed the action; the delegate skill's example workflow ledgers the completion before it removes the task's temporary files, as step 8 says.

## 0.15.48 - 2026-09-30

- An unforeseen gate raised by an evidence-review finding, after every step of the brief ran, gets its own start line, `Every step of the brief is done, its gated action included; never run them again.`, in place of the start-step line, and its post-gate part runs only the commands approved at this gate, or only the checks that verify the owner's fix, where it had no line and the other unforeseen-gate text sent it to steps that had already run.

## 0.15.47 - 2026-09-30

- Owner gate text tidied after the last review: Resuming says its restore runs before the ledger is read and its other steps once the ledger exists, creating the ledger with its identity line first when none exists; the record commit check in the evidence reviewer template and the unforeseen variant of the implementer template require a body that starts with the line `Owner gate: <id>`; the evidence reviewer gets every answer line or the pre-approval line; the delegate skill's example workflow shows the Reconcile line, the evidence review line and the removal of temporary files; its completion line for a gated task allows `<K> parked`; the final fix dispatch takes the findings left after the controller's rulings, and the process graph says so; the re-review template fills `[LIVE_ACCESS]` for a final fix wave that touched a gated task; an unforeseen gate raised by an evidence-review finding names no start step.

## 0.15.46 - 2026-09-30

- A record commit is looked up on the branch only: Resuming and the finish skill's owner gates list run `git log --grep='^Owner gate: <id>$'` over the range from the merge base with the default branch to `HEAD`, where the lookup had no range and an earlier plan's record commit with the same gate ID on the default branch read an unacted gate as acted.

## 0.15.45 - 2026-09-30

- Every fix dispatch for a gated task after its post-gate part has acted, resumed or fresh, and the final review's fix wave whenever it touches a gated task, carries a fix-round `[OWNER_GATE]` text of the implementer template, where it carried the post-gate block: that block's pin checks and dry-run re-check fail by construction once the action has run, so each such dispatch reported BLOCKED, and its "end with the record commit" invited a second record commit.
  The fix-round text says the approved run is done, forbids running the commands again and any other effect outside the repository, skips the pin and dry-run checks, limits the fix to what the findings name, and makes no second record commit.

## 0.15.44 - 2026-09-30

- The owner gate protocol's Resuming and the evidence reviewer template cover a resumed evidence review whose reports and pinned temporary files are gone with the workspace: the run ledgers `State: workspace lost before the evidence review of Task N; reports and temporary files gone`, and the reviewer checks the live state against the pins and the evidence in the record commit's body and the ledger's gate lines, in place of the missing files, as under `build:execute`, where neither text said what to review against.

## 0.15.43 - 2026-09-30

- `delegate`'s and the owner gate protocol's one-run guard covers the final review's fix wave whenever it touches a gated task, which carries the post-gate `[OWNER_GATE]` block with its one-run sentence like every other fix dispatch after the post-gate part has acted, where the rule named only the task's own fix rounds.

## 0.15.42 - 2026-09-30

- Both executors' final review rules on a final finding that conflicts with the plan or the owner gate protocol, or that needs no change to the branch, and ledgers the ruling, as in the task loop, and the fix wave takes the rest, where the final review sent every finding to the one fix wave and a finding that needed no change became a fix or an unrecorded skip.

## 0.15.41 - 2026-09-30

- The owner gate protocol's Resuming names the ledger line for what the reconciliation with `git log` found, `Reconcile <time>: <since>..HEAD; <what it recovered, or "nothing to recover">`, on a fresh start and after a restore alike, with an example among the ledger lines, where it named no line and a run recorded the result as a `Resume` line or not at all.

## 0.15.40 - 2026-09-30

- Both executors read the owner gate protocol at setup and follow its Resuming before they read or create the ledger, also on a fresh start with no ledger, because a lost workspace looks like one and only `git log` shows a gated task that has already acted, where they read the protocol before the first gated task and followed Resuming "whether or not the run paused", which a run starting a gated plan read as not applying to a fresh start, even after the example workflow showed the reconciliation.

## 0.15.39 - 2026-09-30

- `delegate`'s example workflow follows Resuming at the setup of its gated plan and reads `git log` from the merge base before it starts fresh, where it went from "no ledger inside" straight to a fresh start, against the setup rule, and a run started a gated plan the same way.

## 0.15.38 - 2026-09-30

- The owner gate protocol's evidence review names the gate's ledger lines it passes, verbatim: the pre-gate line with its pins, and every answer line or the pre-approval line, as the evidence reviewer template's `[GATE_LINES]` does, where step 7 said only "this gate's ledger lines", so a run passed the `waiting for owner` and `post-gate: dispatched` lines and left out the owner's answer and the pins.

## 0.15.37 - 2026-09-30

- `delegate`'s pre-gate dispatch comes from the implementer template with the template's pre-gate `[OWNER_GATE]` text verbatim, in the owner gate protocol's step 1 and the Owner gates section, where only the post-gate dispatch was tied to the block, so a resumed run wrote a short pre-gate prompt of its own that dropped "leave every file the gate shows or acts on in place".

## 0.15.36 - 2026-09-30

- `delegate`'s scoped re-review after an evidence-review fix gets read-only access to the live system whatever its findings are about, and confirms with one read-only call that the fix round took no effect there, where the template called `[LIVE_ACCESS]` optional and tied it to a finding about live state, so a run left it out for a fix to a record commit's message and told the re-reviewer not to look at the live system.

## 0.15.35 - 2026-09-30

- Resuming in `delegate`'s owner gate protocol runs `execution-status restore` also when a ledger is present, and ledgers the text it printed after its `execution-status:` prefix, verbatim, on a `Resume` line of its own, where a run with a ledger in place skipped the restore and another wrote its own summary of the reconciliation in place of what the restore printed.

## 0.15.34 - 2026-09-30

- `delegate`'s owner gate protocol takes an owner's answer's time from `date` run when the answer arrives, and every time in a ledger line from `date` run when the line is written, where it named the command but not when to run it, so a run ledgered a "later" and its Pause line with the time it had taken before sending the gate message.

## 0.15.33 - 2026-09-30

- The completion of a task with an owner gate removes its temporary files in `delegate`'s Complete the task and in `execute`'s Owner gates section, as the owner gate protocol's step 8 says, where neither executor's completion text named the removal, so a run completed a gated task and left its pre-gate artifact behind.

## 0.15.32 - 2026-09-30

- `delegate`'s owner gate protocol ledgers the evidence review's verdict as `Task N: evidence review clean` or `Task N: evidence review: <K> findings (<one-liners>)` before any fix round, where it named no line for it, so a run wrote its own form and Resuming, which reads the ledger for an evidence review in progress, had no line to find.

## 0.15.31 - 2026-09-30

- The implementer template says a gated task has two reports, one per part, named after their briefs, where `[REPORT_FILE]` described one report per task, and the README says the ledger is copied into the plan when a run pauses, which covers a pause before a task as well as one at a gate.

## 0.15.30 - 2026-09-30

- `delegate`'s scoped re-review template gains an optional `[LIVE_ACCESS]` section with the evidence reviewer's rules for read-only calls (never the gated action or anything that takes effect, one focused call per named check), filled for a re-review after an evidence-review fix, where the Owner gates section promised that re-review read-only access to the live system but the template had no slot for it.

## 0.15.29 - 2026-09-30

- An unforeseen gate's resume, review and post-gate brief are complete: a resumed run pins the artifact again after re-running the steps that produced it, the rationalization rows on a lapsed approval name the unforeseen-gate exception, and an owner-performed unforeseen gate's post-gate part starts at the first step after the owner's action, in the protocol and in the implementer template, where it started at Step K+1, which can be that action.
  `execute` keeps the task's original BASE for an unforeseen gate's evidence-review package and `task-done`.
  The evidence reviewer gets the task's whole brief and `gate-<id>.md` for an unforeseen gate, pinned or not, in place of the two part briefs.
  An unforeseen gate raised inside a task the plan gated gets that task's post-gate brief with the start-step line, not the whole brief.

## 0.15.28 - 2026-09-30

- `delegate`'s Owner gates section and the owner gate protocol's evidence review step say that every fix dispatch for a gated task after its post-gate part has acted, the fresh implementers of rounds 4 and 5 and the fallback when the harness cannot resume included, carries the post-gate `[OWNER_GATE]` block with its one-run sentence, where only rounds 1 to 3, which resume the post-gate implementer, were said to be limited to one run of the approved commands.

## 0.15.27 - 2026-09-30

- `delegate`'s owner gate protocol reconciles the ledger with the commits since the merge base with the default branch, always, where it read from the pause commit when the plan had one, a window that misses a `pause before Task N` commit made after the record commit of a gated task whose evidence review was still running.
  A gated task whose record commit is in the log gets its `Gate <id>` line only when the ledger lacks one, and resumes its evidence review or fix loop at the next round when the ledger shows one in progress, where it restarted at the evidence review.

## 0.15.26 - 2026-09-30

- A record commit is found by its first body line, `Owner gate: <id>`, with `git log --grep='^Owner gate: <id>$'`, in `delegate`'s owner gate protocol, `execute`, `finish` and the implementer template, and `plan` says the body starts with that line, where a record commit was any commit whose body named the gate ID, which also matched an earlier commit that only mentioned the gate.

## 0.15.25 - 2026-09-30

- `delegate`'s `task-brief` reads an Owner Gates index Task cell of "Task 6" as task 6, so a task indexed that way without its marker is refused, where only a bare "6" was matched and the task extracted as ungated.

## 0.15.24 - 2026-09-30

- `delegate`'s owner gate protocol keeps the commits of an unforeseen gate whose run-time approval lapsed: a resumed run re-runs only the steps that produced its artifact, and only when the artifact is missing or its pin no longer matches, then asks again, where it said to re-run the whole pre-gate part, commits included.
  A recovered gated task whose BASE was lost with the workspace takes the parent of its first commit in the log as BASE for its evidence review, where nothing said which BASE to use.

## 0.15.23 - 2026-09-30

- `delegate`'s owner gate protocol shows one `Artifact:` line per pinned file and quotes the `Show` file for a pinned file that is not text, removes a task's temporary files only once its evidence review is clean, since the reviewer checks against them, and replaces only the character a hook rejects in a verbatim answer, or a `|` that would break a table, with its plain form.
  A session the owner ends with no task at its gate pauses with `docs(plan): pause before Task N`, which Resuming reads from too; the ledger never holds a secret; Pausing spells out the post-gate argument of `execution-status write`; the pre-approval check passes a gate only for an action the approval pins, where it could pass a gate that "Who performs the action" says must ask.
  `delegate` says a gated task has two reports, one per part, and its implementer template joins the pre-gate exception to "Every task ends with at least one commit"; `plan` agrees on temporary files and on replacing a character in a pre-approval.

## 0.15.22 - 2026-09-30

- `WORKFLOW.md`, symlinked into `plan`, names the executor's "Owner gates" list beside "Rulings I made" and "Deferred minors" at the second review gate.
  `plan` names the user's two review gates where it said "two gates", leaves the owner gates clause out of the first handoff template when the plan declares none, and words self-review item 7 without the undefined "stop-list action".

## 0.15.21 - 2026-09-30

- `finish` runs `execution-status restore` whenever the plan holds an Execution status, which keeps a longer ledger, where it ran only when `progress.md` was missing, and takes the pull request's "Owner gates" list from the record commits since the merge base, one entry per gate with its answer or pre-approval and the record commit's hash, where it took every `Gate` line of a ledger that may be gone.
  `delegate`'s and `execute`'s Finish paragraphs say one entry per gate, that `build:finish` puts three lists in the description, not two, and that it reads the owner gates too.

## 0.15.20 - 2026-09-30

- `delegate`'s `execution-status write` gives a ledger without a final newline one, where the closing fence joined the ledger's last line and `restore` then found no fenced ledger; refuses a ledger line of four backticks after any indentation, where only an unindented one was caught although the fence tracker ends the fence at either; and refuses a RESUME_AT holding a newline.

## 0.15.19 - 2026-09-30

- `delegate`'s `pin` refuses a directory, a file it cannot read and a hash that did not come out, with exit 2 and a message naming the file, before it prints any line, where a file without read permission printed `sha256: <file>` with an empty hash and exited 0, and `--check` reported an empty hash as a mismatch.

## 0.15.18 - 2026-09-30

- `delegate`'s owner gate protocol pins the artifact of an unforeseen gate: its `Show` is the written statement plus any artifact the stopped part produced, which becomes its `Acts on`, and the owner performs an action with nothing to pin, where the statement alone was pinned and the artifact that then got applied never was.
  Its post-gate part gets the whole brief and the step to start at, since `task-brief --part` refuses an ungated task, and builds on the commits made before the stop; the implementer template and `execute` say so.

## 0.15.17 - 2026-09-30

- `delegate`'s owner gate protocol voids a pre-approval for the run when a pin check or dry-run re-check of its gate fails, and ledgers `Gate <id>: approval void (<the check that failed>)`, where the gate went back to step 1 and the pre-approval check passed it again without asking.
  Resuming reads that line as a post-gate part that stopped without acting.

## 0.15.16 - 2026-09-30

- `delegate`'s implementer template tells a post-gate implementer that the approval covers one run of the approved commands, and that in a fix round it never runs them again and takes no other effect outside the repository but reports BLOCKED, where a fix round resumed the implementer that held the approval and a finding about the live system invited a second apply.
  Both executors screen the evidence review's findings before any fix, so one whose fix needs another live action becomes an unforeseen gate, and `delegate`'s scoped re-review after an evidence-review fix gets read-only access to the live system.

## 0.15.15 - 2026-09-30

- `delegate`'s owner gate protocol reconciles the ledger with `git log` at every setup of a plan that declares owner gates or holds an Execution status, reading from the pause commit or else from the merge base, where it did so only after a pause; so a record commit whose completion was never ledgered, or a workspace lost without a pause, no longer lets a gated action run twice.
  A run-time approval lapses when the session that received it ends before the post-gate part starts, at a pause or not, where the text said only "at a pause".
  `delegate` and `execute` follow this at setup, say that `PLAN_FILE` is the plan's path relative to the repository root in the ledger's identity line and every script call, and join the resume rule with its gated-task exception.

## 0.15.14 - 2026-09-30

- `delegate`'s `task-brief` refuses (exit 3) a step title that says "owner gate" without being a well-formed marker, such as the Title Case `Owner Gate`, and a task that the Owner Gates index names but whose steps hold no marker with that ID, where it extracted either task as ungated, the gated action included; a step titled "Owner gateway" is no longer taken for a malformed marker.
  `plan` tells plan authors so.

## 0.15.13 - 2026-09-30

- `execute`'s `## Owner gates` asks for `Task N post-gate: started` to be ledgered before any post-gate step runs, in any call, where it also required the same call as `task-start --part post-gate`.

## 0.15.12 - 2026-09-30

- `execute`'s `task-done` skips lines of only whitespace, a carriage return included, when it picks the last output line for the ledger, so a check whose output ends with a spinner clearing its line records its last real line.

## 0.15.11 - 2026-09-30

- `delegate`'s owner gate protocol no longer says the gate message's lines are exact: the message keeps the plan's text verbatim in a `text` fence with more backticks than any fence it quotes, a gate pinned by a command's text shows `Command:` in place of the `Artifact:` line, and a gate the owner performs shows a `Commands:` line and asks for "done", where the exact template ended in "Answer yes, no with what to change, or later." and read as letting a "yes" pass an owner-performed gate.

## 0.15.10 - 2026-09-30

- `delegate`'s Resuming section recovers a gated task whose record commit is in the log by ledgering its gate answer and resuming at its evidence review, which completes it, where it could be ledgered complete without that review; a post-gate line with a record commit after it no longer triggers the unforeseen-gate safeguard, and the ledger example shows a recovered completion.

## 0.15.9 - 2026-09-30

- The evidence reviewer prompt reads the task's ledger lines and record commit where an inline executor wrote no report files, and `execute`'s `## Owner gates` says to pass them in place of `[PRE_GATE_REPORT]` and `[POST_GATE_REPORT]`, where the template marked the two report files as required.

## 0.15.8 - 2026-09-30

- `delegate`'s owner gate protocol reconciles a restored ledger with the commits after the pause commit: it ledgers the tasks those commits complete as recovered from `git log`, resumes at the first task they do not complete, and never re-runs the post-gate part of a gate whose record commit is in the log, where the copy in the plan, as old as the pause commit, would have had a resumed run redo the tasks and a pre-approved gate act a second time.

## 0.15.7 - 2026-09-30

- `execute`'s `task-done` records a passing test command that prints nothing, with `(no output)` as the last line, where it exited 1 under `pipefail` and recorded nothing although the check passed.

## 0.15.6 - 2026-09-30

- `execute` names `workspace`, `execution-status restore` and `review-package` by their path from its own directory and runs them from the repository root, and `delegate` runs `review-package` from the repository root, where both said to run them from the skill's directory, which an executor read as changing into it, so the scripts resolved the repository that holds the skill.

## 0.15.5 - 2026-09-30

- `delegate`'s owner gate protocol sends the gate message as a single `text` fence, since the instruction to add no formatting alone still let an executor put the gate ID in backticks.

## 0.15.4 - 2026-09-30

- `delegate`'s owner gate protocol places the artifact's quote below the gate message's `Artifact:` line, so a message sent exactly as its template shows it still quotes the artifact.

## 0.15.3 - 2026-09-30

- `delegate`'s owner gate protocol ledgers every answer at a gate verbatim with its time, a "later" too, so the ledger shows that the owner paused the run.

## 0.15.2 - 2026-09-30

- `execute` ledgers `Task N post-gate: started` in the same call as `task-start --part post-gate`, before any post-gate step runs, so a run lost after the gated action still shows a started post-gate part when it resumes.

## 0.15.1 - 2026-09-30

- `delegate`'s owner gate protocol says the gate message's lines are sent exactly as its template shows them, with no backticks or other formatting added, so its first line always reads `Owner gate <id> (Task N)`.

## 0.15.0 - 2026-09-30

- `WORKFLOW.md`, symlinked into `plan`, names the review gates and the owner gates: the user pre-approves owner gates by ID at the first review gate, the executors stop only at owner gates, every stop runs the same protocol, and the Execution status and the record commits are listed with what gets written where. The README says so.

## 0.14.0 - 2026-09-30

- `finish` recreates a paused run's ledger from the plan's Execution status before it removes the plan, and the pull request description lists the owner gates: each gate's ID, the answer or the pre-approval, and the record commit of its task.

## 0.13.0 - 2026-09-30

- `plan` writes owner gates: a gate step with its ID and fields in the task that performs a hard-to-reverse action, the rules for the steps before and after it and for who may perform the action, and a `### Owner Gates` index as the first subsection of the plan. Every task ends with at least one commit. The handoff lists the gates that can be pre-approved and asks which, by ID; the answer goes into the index, committed as `docs(plan): record pre-approved owner gates`. Self-review checks the gates.

## 0.12.0 - 2026-09-30

- `execute` runs a task with an owner gate as `delegate`'s `references/owner-gates.md` says, doing both parts itself and dispatching the evidence reviewer, since its final review cannot see live state. `task-start` takes `--part pre-gate|post-gate` and passes it to `task-brief`. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates. Its stop list names the owner gates the plan declares next to the five stops.

## 0.11.1 - 2026-09-30

- `delegate` names the owner gates the plan declares next to the five stops in three sentences that still said only the five stops stop the executor.

## 0.11.0 - 2026-09-30

- `delegate` runs a task with an owner gate as `references/owner-gates.md` says: two dispatches around the gate, which the controller takes; a pre-approved gate passes without asking; the post-gate dispatch is fresh and carries the approval; an evidence review takes the place of the diff review. Each of the five stops that the plan did not declare runs the same protocol as an unforeseen gate. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates next to the rulings and deferred minors.

## 0.10.0 - 2026-09-30

- `delegate` gains `references/owner-gates.md`, the protocol both executors follow at an owner gate: the two parts of a gated task, who may perform the action, the pins, the pre-approval check, the gate message, the record commit, unforeseen stops, pausing and resuming, and the ledger lines. `references/evidence-reviewer-prompt.md` reviews a gated task against the approved artifact, the record commit and the live system through read-only calls. The implementer template ends every task with at least one commit, a record commit for work outside the repository, instead of letting a brief declare that a task commits nothing, and carries an optional `## Owner Gate` section for the two parts.

## 0.9.0 - 2026-09-30

- `delegate` gains `scripts/execution-status`. `write PLAN RESUME_AT` copies the ledger verbatim into an `## Execution status` section of the plan, replacing an earlier one in place and leaving every other line as it was; `restore PLAN` recreates a missing ledger from that copy, replaces a ledger the copy extends, keeps one that extends the copy, and exits 1 when they disagree.

## 0.8.0 - 2026-09-30

- `task-brief` ends a task at the next heading of the same or a higher level, so the last task no longer carries a later section, such as an Execution status, into its brief; it tracks fences by character and length, so a fence inside a longer one stays text. A task with an owner gate is extracted in two parts: `--part pre-gate` writes `task-N-pre-gate-brief.md` (the steps before the gate, the gate and a line that stops the implementer there) and `--part post-gate` writes `task-N-post-gate-brief.md` (the gate and the steps after it). Before it writes anything, it refuses a task with two gates, a gate missing a field or giving one twice, a performer other than `agent` or `owner`, an ID that is not kebab-case, is duplicated or is missing from the Owner Gates index, a gated task without `--part` and an ungated task with it.

## 0.7.0 - 2026-09-30

- `delegate` gains `scripts/pin`, which prints a file's sha256 in the form an owner gate records (`sha256:<hex> <file>`) and checks a file against a recorded pin with `--check`, using `sha256sum` or `shasum`. The build scripts have fixture tests in `tests/scripts.sh`, which also prove that `review-package` accepts a range holding only an empty record commit.

## 0.6.0 - 2026-09-29

- `finish` asks once before the push unless the user's standing instructions cover pushing and opening a pull request; under the Lyngon workflow, `conventions:engineering`'s do, and it pushes without asking as before. `WORKFLOW.md` names `conventions:engineering` only under a "With the Lyngon workflow" heading. The README lists the deferred-findings question after the pull request, where `finish` asks it. `plan`, `execute` and `delegate` say the push is left to `finish` instead of saying it is never a stop.

## 0.5.0 - 2026-09-29

- `plan`, `execute` and `delegate` name the pull request as the user's second gate, and the executors no longer stop for pushing the feature branch or opening its pull request. `WORKFLOW.md` puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request. The plugin's description ends at an open pull request instead of an integrated branch.

## 0.4.0 - 2026-09-29

- `finish` pushes the branch and opens the pull request without asking instead of presenting a menu, and merges locally or keeps the branch only on request. The description carries what changed, decisions for the user, the executor's rulings and deferred minors with a link to the plan, unfixed findings and the verification. An existing pull request gets its description updated; without a remote the branch is kept, and without a forge CLI the creation link is handed over. Deferred findings go into the description, and the question which of them go to `docs/TODO.md` comes after the pull request is open.

## 0.3.0 - 2026-09-29

- `plan` requires every check the plan mandates (a script, a command with an expected output, a condition a task verifies before it proceeds) to be shown failing when its property does not hold and passing when it does. A check without that control is a placeholder, and self-review looks for it.
- `plan` self-review checks every block of prose the plan dictates (ADR text, README steps, `CLAUDE.md` lines, `CONCEPTS.md` entries) against the existing ADRs, the gates and rules in `CLAUDE.md`, and the findings recorded earlier in the design and plan.
- `plan` writes a command a person runs by hand in POSIX sh or through `bash -c`, and points at `conventions:shell` for the rules of scripts.

## 0.2.0 - 2026-09-29

- Task briefs carry the plan's Global Constraints section after the task text. The task reviewer reads them in the brief; the controller adds at most one sentence of emphasis instead of pasting them.
- `task-brief` and `review-package` print only the file path on stdout and their summary on stderr, so `B=$(task-brief ...)` captures the path.
- One brief and one report per task. A report file left by an earlier attempt is handed to the new implementer, who reads it first and appends under a dated heading.
- Review packages list every commit with its full message, so reviewers can check the commit rules.
- Every reviewer gets the state changes since the plan was written, ledgered as `State:` lines, in an optional section.
- The implementer template tests and commits as the brief says, with the previous behaviour as the default, and a brief may declare that a task commits nothing. Hook evidence is the output of an explicit hook run, never commit-time output; with devenv, `prek run --all-files`.
- `delegate` and `execute` hand the plan workspace to `finish` instead of deleting it. `finish` offers the deferred minors and parked findings for `docs/TODO.md` before it removes the plan, and removes the workspace when the work lands.
- `finish` ends a pull request with the landing steps for after the forge merges it: switch to the base branch, `git pull --ff-only`, remove the worktree and delete the local branch.

## 0.1.0 - 2026-09-23

- Added `plan`, `execute`, `delegate` and `finish`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`) and rewritten to Lyngon vocabulary: plans in `docs/plans/` on the branch, the ledger in `tmp/build/`, one commit per task on a feature branch, review at the plan and the branch, no package installs, and the worktree skill folded into the executors' setup.
- `plan` links the shared `WORKFLOW.md`, which lays out the flow between the discover, build, practice and review skills and the user's gates.
