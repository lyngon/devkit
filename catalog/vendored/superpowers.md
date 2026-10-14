# superpowers

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream version**: 6.4.1
- **Upstream license**: MIT (see [LICENSE-superpowers](../../shared/LICENSE-superpowers))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

### `plugins/build/skills/delegate`

The thorough executor: a fresh implementer per task so no context pollutes another, a spec-and-quality review after every task, a bounded fix loop with a breaker, and a whole-branch review at the end.
With the user reviewing only the plan and the finished branch, this per-task reviewer is what replaces the human eye on every commit.

### `plugins/build/skills/execute`

The inline executor: one context does every task of a plan, writing the tests and the code the plan leaves to its implementer, with a ledger that survives compaction so a resumed session never redoes a finished task, and one fresh reviewer at the end.
It is the cheap execution mode; `build:delegate` is the thorough one, and both share a workspace so a plan can switch executor mid-flight.

### `plugins/build/skills/finish`

Both executors end here.
It turns a finished branch into the user's second review gate: full check green, plan file removed, then the branch pushed and its pull request opened for the user's review.
The discard path with a typed confirmation and the ownership rule for worktree cleanup are the safety the executors rely on.

### `plugins/build/skills/plan`

Nothing in the devkit turned a settled design into an executable plan.
This skill's task shape (files, interfaces, no placeholders) is what lets a fresh implementer or a mid-tier model execute without the designer's context, and its self-review catches the gaps before execution starts.

### `plugins/discover/skills/approach`

The skill is vendored from mattpocock/skills, and [mattpocock.md](mattpocock.md) records that upstream.
Since 2026-09-23 it also carries the classification and approval gate from superpowers `brainstorming`, so every piece of work gets a design in the smallest form it needs before anything is built.

### `plugins/practice/skills/debug`

The engineering conventions say to start a bug fix by reproducing it end to end; this is the full procedure, with the three-failed-fixes rule that turns a thrashing session into an architecture question, and three techniques (backward tracing, defense in depth, condition-based waiting) that come up in every codebase.

### `plugins/practice/skills/tdd`

The engineering conventions say to reproduce a bug first and to keep the reproduction as a regression test; this skill is the procedure that makes an agent do that under pressure, with the rationalizations it will reach for named and answered.
`writing-good-tests.md` is the sharpest short text we have on tests that catch real breaks rather than mock behaviour.

### `plugins/practice/skills/verify`

The shortest skill in the set and the one that closes the gap between "should pass" and "passed": a claim needs the command and its output in the same message.
The engineering conventions say to report faithfully; this is how.

### `plugins/review/skills/receive`

The other half of review.
It stops the two failure modes that waste a review: agreeing performatively and implementing blindly.
With the user reviewing the finished branch, feedback arrives in batches, and the rule to clarify every unclear item before implementing any of them is what keeps a batch from being half-applied.

### `plugins/review/skills/request`

Both executors need a reviewer that takes a plan, a review-focus list and the executor's rulings, which a generic review command does not.
The template gives the reviewer exactly that context and nothing of the requester's session, and its "declined to judge" list stops findings from being dropped silently.

## What was taken

| Upstream path | Destination |
| --- | --- |
| `skills/subagent-driven-development` | `plugins/build/skills/delegate` |
| `skills/executing-plans` | `plugins/build/skills/execute` |
| `skills/finishing-a-development-branch` | `plugins/build/skills/finish` |
| `skills/writing-plans` | `plugins/build/skills/plan` |
| `skills/brainstorming` | `plugins/discover/skills/approach` |
| `skills/systematic-debugging` | `plugins/practice/skills/debug` |
| `skills/test-driven-development` | `plugins/practice/skills/tdd` |
| `skills/verification-before-completion` | `plugins/practice/skills/verify` |
| `skills/receiving-code-review` | `plugins/review/skills/receive` |
| `skills/requesting-code-review` | `plugins/review/skills/request` |

## Local patches

### `plugins/build/skills/delegate`

- Renamed `subagent-driven-development` to `delegate`.
- Description rewritten to say what the skill does and when to use it, and that it is the default executor for more than a handful of tasks.
- Skill references remapped: `superpowers:executing-plans` to `build:execute`, `superpowers:requesting-code-review` to `review:request`, `superpowers:finishing-a-development-branch` to `build:finish`, "brainstorm first" to `discover:approach` and `build:plan`.
- Prompt templates moved from the skill directory into `references/` (`implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`); links and graph node labels updated. In each template, `Subagent (general-purpose):` replaced by `Dispatch a subagent with:`; the `description`, `model` and `prompt` fields, the no-subagents contract, the report contract, the four statuses and the calibration rules kept; the `[MODEL]` note reworded without a dash; the placeholder lists rewritten as bullets with colons; the templates are fenced as `text`.
- Implementer template: the commit step now says one commit per task on the current branch, Conventional Commits, one concern per commit, never on main; added that tools come from the repository's declared environment (never install anything) and that a check or hook is never disabled, skipped or weakened (report instead). Added a placeholder list.
- Task reviewer template: "the human decides" became "the user decides"; "spec/design" became "spec or design".
- Scripts: `sdd-workspace` renamed to `workspace`; base directory changed from `<repo-root>/.superpowers/sdd` to `<repo-root>/tmp/build`, with the self-ignoring `.gitignore` (`*`) written inside `tmp/build/`; comments reworded generically (the `.git/` protection is attributed to agent harnesses in general rather than Claude Code, `tmp/` named as the Lyngon scratch directory, "legacy" marker-less workspaces described as created by hand or by an older version), the plan-path marker logic kept unchanged. `task-brief` and `review-package` call `workspace` and document the new default paths; the "(#2040)" issue reference and "marketplace packages" wording replaced by "some plugin installers strip Unix exec bits"; the two `CDPATH= cd` idioms in `workspace` became `CDPATH='' cd` so the script is clean under the repository's shell lint (same behaviour). Exec bits kept.
- Setup: the worktree paragraph pointing at `superpowers:using-git-worktrees` replaced by an `### Isolated workspace` section (ask once, prefer the harness's native worktree tool, fall back to `git worktree add .worktrees/<branch>` with `.worktrees/` git-ignored, no package installs, never on main without consent, the plan is already committed on the branch, implementers work in the worktree) with a `#### With devenv` subsection.
- Ledger: first line changed from the upstream `# SDD ledger` header (which carried an em dash) to `# build ledger: plan <path>`; the clause about a stray ledger at the old flat path `.superpowers/sdd/progress.md` removed; added that `tmp/` may be emptied at any time.
- Spec pointer: "If the plan names a Spec" became "the `## Design` section of the same file, otherwise the external spec the plan header points at".
- Stop conditions: the four upstream stops plus a fifth (a check or hook that could only be passed by disabling, skipping or weakening it), the rule never to do so and never to let an implementer do so; two rationalization rows added (skipping a failing hook, checking in between tasks). "the four named below" became "the five named below".
- Continuous execution names the user's two review gates.
- Final review: the cross-plugin file reference `[code-reviewer.md](../requesting-code-review/code-reviewer.md)` replaced by invoking `review:request`, which carries the template; inputs listed as the review package path, the plan and its Design section, the Review Focus verbatim, and the ledger's deferred-minor, parked and `Ruling:` lines. The graph node renamed accordingly.
- Finish: "Deferred minors" list added next to "Rulings I made" (upstream collected only rulings), so `build:finish` can open the pull request description with both; ends by calling the Skill tool for `build:finish`.
- Ledger line formats use semicolons where upstream used em dashes (`Ruling: <what>; <why>; <cost>`, `Task <N>: parked; <finding>; Ruling: <why>`, the fix round line).
- Model selection: "standard model" became "mid-tier model" so the three tiers read cheap, mid-tier, most capable; no vendor model named (as upstream). "Task complexity signals" rewritten as a bullet list without arrows.
- Example workflow: paths rewritten to `docs/plans/2026-09-23-recovery.md` and `scripts/workspace`; the answer `~/.config/superpowers/hooks/` replaced by a neutral one; the opening announcement dropped; the "Rulings I made" and "Deferred minors" lists shown; closing line invokes `build:finish`.
- The "When to use" graph: nodes renamed to `build:delegate`, `build:execute` and "Manual execution, or discover:approach and build:plan first"; "Partner chose inline" became "User chose inline".
- "Announce at start" line dropped; "your human partner" replaced by "the user" throughout.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; the numbered BLOCKED list ends each item with a full stop; bold labels end in a full stop or colon.
- `task-brief` and `review-package` print the bare path on stdout and their summary on stderr, where upstream printed `wrote <path>: ...` on stdout while SKILL.md said they print the path.
- `task-brief` appends the plan's `### Global Constraints` section after the task text, found by the same fence-aware awk pass (a plan without one gives a brief without it); the "not found" check still looks at the task text only. The task reviewer template's `[GLOBAL_CONSTRAINTS]` (the controller pasted the constraints) became a pointer to the brief's Global Constraints section plus an optional one-sentence `[CONSTRAINT_EMPHASIS]`; the "attention lens" paragraph in SKILL.md was rewritten to match.
- One brief and one report per task: "a uniquely named file" dropped; SKILL.md says regenerating a brief is harmless, and that a report file that already exists is a prior attempt's memory, kept and handed to the new implementer with the framing of fix rounds 4 and 5. The implementer template reads an existing report first and appends under a dated heading; the task reviewer template says the last dated attempt is the report on the diff.
- `review-package` lists every commit with its full message (`### <short sha> <subject>`, then the body) instead of `git log --oneline`, so reviewers can check the commit rules; the task reviewer and re-review templates say so, and their fallback adds `git log`.
- Task reviewer and re-review templates: an optional "State Changes Since the Inputs Were Written" section (`[STATE_CHANGES]`), filled from new `State: <fact>` ledger lines that SKILL.md hands to every reviewer, the final one included.
- Implementer template: tests and commits follow the brief, with the defaults stated (tests as `practice:tdd` requires; one commit per task on the current branch, Conventional Commits, never on main), and a brief may declare that the task commits nothing. The report contract asks for hook evidence from an explicit run (`[HOOK_COMMAND]`) and says commit-time hook output never counts; a `## With devenv` section after the placeholders names `prek run --all-files` inside the devenv shell and says `devenv test` is not hook evidence. The devenv sentence sits outside the fenced prompt because the prerequisite validator does not read headings inside a fence.
- Finish: the workspace is handed to `build:finish` instead of deleted (upstream deleted it here), so the ledger's deferred minors and parked findings reach `build:finish`; the graph node, the Finish section and the example say so, and a rationalization row was added. "The only place" the rulings reach the user became "where".
- The second gate is the pull request that `build:finish` opens, and the final message's two lists and residual findings go into its description. The stop list's side effects are the ones the user's standing instructions leave to them (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish); pushing the feature branch and opening its pull request are left to `build:finish`, which asks before the push unless the user's standing instructions cover it. Deferred minors are triaged for what must be fixed before the pull request.
- Added `scripts/pin`, which is not upstream: it prints `sha256:<hex> <file>` for each file and checks a file against a pin with `--check`, using `sha256sum` or `shasum -a 256`; the owner gate protocol pins what an approval covers with it.
- `task-brief`: a task ends at the next heading of the same or a higher level, where upstream ran it to the next task heading and let the last task run to the end of the file; fences are tracked by character and length, where upstream toggled on every line starting with three backticks; `--part pre-gate|post-gate` extracts the two parts of a task with an owner gate; malformed gates are refused with exit 3, and the brief is written to a temporary file that is moved into place only on success.
- Added `scripts/execution-status`, which is not upstream: it writes a paused run's ledger into the plan's `## Execution status` section and restores the workspace's ledger from it.
- Added `references/owner-gates.md` and `references/evidence-reviewer-prompt.md`, which are not upstream. Implementer template: every task ends with at least one commit, a task whose work lies outside the repository with a record commit (empty when nothing changed), replacing "a brief may declare that the task commits nothing"; an optional `## Owner Gate` section (`[OWNER_GATE]`) tells a pre-gate implementer to stop at the gate, and a post-gate implementer what the approval covers and to check the pins first.
- Owner gates, which are not upstream: continuous execution names the review gates and the owner gates; the five stops run the protocol in `references/owner-gates.md`, as unforeseen gates when the plan did not declare them; the process graph branches on a gated task; setup restores a paused run's ledger with `scripts/execution-status restore`; evidence reviews get a model floor; the final review stays after the last task; the final message lists the owner gates; four rationalization rows and a gated task in the example workflow.
- `references/owner-gates.md`, which is not upstream: the gate message is sent as a single `text` fence with more backticks than any fence it quotes; the plan's text stays verbatim and nothing else gets backticks; the artifact's quote goes below the `Artifact:` line, or the pre-gate `Expected:` lines and the file's path when it is over 40 lines; a gate pinned by a command's text shows `Command:`; at a gate the owner performs a `Commands:` line replaces the artifact and the last line asks for "done"; only an explicit yes at a gate the agent performs, or "done" at a gate the owner performs, passes it.
- `references/owner-gates.md`, which is not upstream: every answer at a gate is ledgered verbatim with its time, a "later" too.
- The DONE step runs this skill's `scripts/review-package` from the repository root, where "from this skill's directory" could be read as changing into it.
- `references/owner-gates.md`, which is not upstream: Resuming reconciles a restored ledger with `git log` since the pause commit, recovers completions and gate answers from it, and resumes a gated task whose record commit is there at its evidence review, never re-running its post-gate part.
- `references/evidence-reviewer-prompt.md`, which is not upstream: `[PRE_GATE_REPORT]` and `[POST_GATE_REPORT]` are the task's ledger lines and record commit under an inline executor, which writes no report files.
- `task-brief` refuses (exit 3) a step title that says "owner gate", in any case and followed by anything but a letter, without being a well-formed marker, and a task that a row of the Owner Gates index names but whose steps hold no marker with that row's ID; `references/owner-gates.md` says so.
- `references/owner-gates.md`, which is not upstream: Resuming runs at every setup of a plan that declares owner gates or holds an Execution status, whether or not the run paused, and reconciles the ledger with `git log` since the pause commit, or else since the merge base; a run-time approval lapses when the session that received it ends before the post-gate part starts.
  Setup follows Resuming for such a plan, the resume rule and its gated-task exception are one sentence, and `PLAN_FILE` is the plan's path relative to the repository root in the ledger's identity line and every script call.
- Owner gates, which are not upstream: the evidence review's findings are screened before any fix round, and one whose fix needs another live action becomes an unforeseen gate; the implementer template's post-gate `[OWNER_GATE]` text says the approval covers one run of the commands and that a fix round takes no effect outside the repository; the scoped re-review after an evidence-review fix gets read-only access to the live system.
- `references/owner-gates.md`, which is not upstream: a failed pin check or dry-run re-check is ledgered as `Gate <id>: approval void (<the check that failed>)` and voids a pre-approval too for the run, so step 3 asks, where the gate went back to step 1 and step 3 passed the pre-approved gate again; Resuming reads that line as the post-gate part having stopped without acting.
- `references/owner-gates.md`, which is not upstream: an unforeseen gate's `Show` adds any artifact the part produced, which is its `Acts on` and gets pinned, and the owner performs an action with nothing to pin; its post-gate part gets the whole brief and the step to start at, since `task-brief --part` refuses an ungated task, and builds on the commits made before the stop.
  The implementer template's `[OWNER_GATE]` text has the variant for it.
- `scripts/pin`, which is not upstream: a directory, a file it cannot read and a hash that did not come out are refused with exit 2 and a message naming the file, before any line is printed, where an unreadable file printed `sha256: <file>` with an empty hash and exited 0.
- `scripts/execution-status`, which is not upstream: `write` gives a ledger without a final newline one, refuses a ledger line of four backticks after any indentation, as the fence tracker reads it, and refuses a RESUME_AT holding a newline.
- Finish: the "Owner gates" list holds one entry per gate, and the paragraph says `build:finish` puts three lists in the pull request description and reads the owner gates from their record commits.
- `references/owner-gates.md`, which is not upstream: the gate message has one `Artifact:` line per pinned file and quotes the `Show` file for a pinned file that is not text; a character a hook rejects in a verbatim answer, or a `|` in a table, is replaced by its plain form; temporary files are removed once the evidence review is clean; a session the owner ends with no task at its gate pauses as `docs(plan): pause before Task N`, and Resuming reads from the merge base with the default branch, never from that commit; the ledger never holds a secret; Pausing spells out the post-gate argument of `execution-status write`; step 3 passes a pre-approved gate only for an action the approval pins, as "Who performs the action" requires.
  SKILL.md says a gated task has two reports, one per part; the implementer template joins the pre-gate exception to "Every task ends with at least one commit".
- `references/owner-gates.md`, which is not upstream: when an unforeseen gate's run-time approval lapses, its commits stay and a resumed run re-runs only the steps that produced its artifact, and only when the artifact is missing or its pin no longer matches, then asks again; a recovered gated task whose BASE was lost with the workspace takes the parent of its first commit in the log as BASE.
- `task-brief` reads an Owner Gates index Task cell of "6" or "Task 6" alike when it checks that an indexed task holds its marker.
- Owner gates, which are not upstream: a record commit is the commit whose body has the line `Owner gate: <id>`, where it was any commit whose body named the gate ID.
- `references/owner-gates.md`, which is not upstream: Resuming reads the log from the merge base with the default branch, never from a pause commit, and a recovered gated task ledgers its `Gate` line only when the ledger lacks one and resumes a running evidence review or fix loop at its next round.
- Owner gates, which are not upstream: every fix dispatch for a gated task after its post-gate part has acted, resumed or fresh (rounds 4 and 5, the fallback when the harness cannot resume), and the final fix wave when it touches a gated task, carry the template's fix-round `[OWNER_GATE]` text, since the post-gate block's pin and dry-run checks fail once the action has run.
- Owner gates, which are not upstream: Resuming creates the ledger with its identity line first when none exists and no Execution status recreates it; the completion line of a gated task allows `<K> parked`; the final fix dispatch takes the findings left after the controller's rulings; the example workflow shows the Reconcile line, the evidence review line and the removal of temporary files; the evidence reviewer and re-review templates, and the implementer template's unforeseen variant, follow (record commit body starting with `Owner gate: <id>`, every answer line, `[LIVE_ACCESS]` for a final fix wave that touched a gated task).
- `references/owner-gates.md`, which is not upstream: Resuming looks up a record commit over the range from the merge base to `HEAD`, so an earlier plan's commit with the same gate ID on the default branch never reads as this plan's.
- Owner gates, which are not upstream: an unforeseen gate is pinned again after its artifact is rebuilt on resume, is reviewed against the task's whole brief and `gate-<id>.md`, and in a task the plan gated gets that task's post-gate brief; the implementer template starts an owner-performed unforeseen gate's steps after the owner's action; the lapsed-approval row names the unforeseen-gate exception.
- `references/re-review-prompt.md`, which is not upstream: an optional `[LIVE_ACCESS]` section gives the re-review after an evidence-review fix read-only access to the live system, with the evidence reviewer's rules for read-only calls.
- `references/implementer-prompt.md`, which is not upstream: `[REPORT_FILE]` says a gated task has two reports, one per part, named after their briefs.
- `references/owner-gates.md`, which is not upstream: the evidence review's verdict is ledgered as `Task N: evidence review clean` or `Task N: evidence review: <K> findings (<one-liners>)` before any fix round.
- Complete the task: a task with an owner gate completes as the protocol's step 8 says, with `evidence review clean` and the removal of its temporary files.
- `references/owner-gates.md`, which is not upstream: an answer's time comes from `date` run when the answer arrives, and every time in a ledger line from `date` run when the line is written.
- `references/owner-gates.md`, which is not upstream: Resuming runs `execution-status restore` also when a ledger is present, and its `Resume` line holds the text the restore printed, verbatim, on a line of its own.
- `references/re-review-prompt.md`, which is not upstream: `[LIVE_ACCESS]` is required for every re-review after an evidence-review fix, whatever its findings are about, and the re-reviewer confirms that the fix round took no effect on the live system; Owner gates in SKILL.md says so.
- Owner gates, which are not upstream: the pre-gate dispatch comes from the implementer template with its pre-gate `[OWNER_GATE]` text verbatim, in `references/owner-gates.md` step 1 and in SKILL.md.
- `references/owner-gates.md`, which is not upstream: the evidence review gets the gate's ledger lines verbatim, the pre-gate line with its pins and every answer line or the pre-approval line.
- Example workflow: the setup of the gated plan follows Resuming and reads `git log` from the merge base before a fresh start.
- Owner gates, which are not upstream: `references/owner-gates.md` is read at setup, and Resuming runs before the ledger is read or created, also on a fresh start with no ledger, because a lost workspace looks like one; the setup bullet and `references/owner-gates.md` say why.
- `references/owner-gates.md`, which is not upstream: Resuming names the ledger line for the `git log` reconciliation, `Reconcile <time>: <since>..HEAD; <what it recovered>`.
- Final review: a final finding that conflicts with the plan or the owner gate protocol, or that needs no change to the branch, is the controller's to rule on and ledger; the fix wave takes the rest.
- Owner gates, which are not upstream: the one-run guard on fix dispatches also covers the final review's fix wave whenever it touches a gated task.
- Owner gates, which are not upstream: after a lost workspace, `references/owner-gates.md` ledgers a `State:` line and `references/evidence-reviewer-prompt.md` reviews against the pins, the record commit's body and the gate lines in place of the missing reports and temporary files.
- Owner gates, which are not upstream: an unforeseen gate raised by an evidence-review finding, after every step ran, gets its own start line in `references/owner-gates.md` and the implementer template, and its post-gate part runs only the commands approved at this gate or the checks that verify the owner's fix.
- Owner gates, which are not upstream: the implementer template has a fix-round `[OWNER_GATE]` text for a gate the owner performed, the fix-dispatch rules here and in `references/owner-gates.md` cover it, and the example workflow ledgers the completion before it removes the temporary files.
- State walk, which is not upstream: before a fix dispatch for protocol text (text that names states and the events between them, or a rule that holds across steps, recognized by a sentence that is read on more than one path), the fix loop and the final fix wave write a walk list of the states and paths that read the sentence, each with the outcome it must give, and send it with the findings; `references/re-review-prompt.md` has an optional "The State Walk" section (`[WALK_LIST]`) whose re-reviewer verdicts each entry HOLDS or BROKEN and reads beyond the fix diff for it; such a re-review takes at least a mid-tier model; one rationalization row.
- `task-brief` reads a task's slug from its heading and names the brief by it (`task-N-slug-brief.md` and the two part names); it refuses a slug that is not kebab-case, is `pre-gate` or `post-gate`, or is shared by two task headings, and its `--label` mode prints `Task N slug` (or `Task N`) without writing a file.
- Model selection, which is not upstream: a mid-tier model for the implementer of every plan task, the cheapest tier only for a batch of same-shape edits and a single-file mechanical fix, the most capable for work that judges other work; the signals list follows; the plan scan compares acceptance lines with Interfaces and dictated text with States; exact values in a dispatch include acceptance lines and dictated text.
- Handle the report, which is not upstream: a BLOCKED report that names a state and a sentence of dictated text is ruled on with the smallest rewording, ledgered with a `State:` line, and re-dispatched with the new sentence.
- `references/implementer-prompt.md`, which is not upstream: "Your Job" builds what Intent and acceptance lines require, writes a failing test per acceptance line and places dictated text as written; a "Dictated Text and States" section has the implementer read the text in each state and report BLOCKED on a conflict; the report format gained Acceptance, Task test command and States.
- Handle the report and Review the task, which are not upstream: a report without its Acceptance item or task test command is incomplete and the implementer is resumed before the review; the task reviewer runs the task's own test files once with the reported command; the example workflow shows a verdict per acceptance line and a covering test per line in the implementer's report; one rationalization row.
- `references/task-reviewer-prompt.md`, which is not upstream: "Tests" has the reviewer run the reported task test command once, and "Part 1: Spec Compliance" gives a verdict per acceptance line (COVERED, MET, MISSING) and per state (HOLDS, BROKEN) and reads the whole of the files the dictated text sits in; the output format lists Acceptance, States and Tests run.
- The task loop, which is not upstream: a fresh subagent whose dispatch has a prompt template reads the template's prompt itself, from a file; the dispatch names that file, fills each placeholder by its name and says which sections do not apply, and the controller never pastes, condenses or rewords a template. "Reviewer inputs" names the prompt file beside the three paths.
- Added `scripts/prompt-file`, which is not upstream: it writes the prompt of a template (the content of its first fenced `text` block after the `prompt: |` line, without the block's indentation, the dispatch lines above it and the notes below it) to `prompt-<template name>` in the plan's workspace and prints the path; a template without such a block or without a `prompt: |` line is refused with exit 3 and nothing written.
- Workspace and ledger, which is not upstream: a ledger line whose format starts with `<label>` starts with the label, with nothing before it, a time included; a time goes only where a format has `<time>`.
- Tasks are named by their label (`Task 3 rate-limiter`, or `Task 3` without a slug) in every ledger line format, in the owner gate protocol and in the dispatch descriptions of the four templates, which gained a `[LABEL]` placeholder; brief and report names carry the slug and a report is named from its brief with `-report.md` in place of `-brief.md`.
- `task-brief` reads an Owner Gates index Task cell as the task's number, with or without `Task` before it and a slug after it, and refuses a cell whose slug differs from the slug of the task's heading or that has one where the heading has none (the former line reading "6" or "Task 6" alike is superseded).
- `task-brief` refuses, with the line's number, a line that would open a fence while a fence of the same character and at most that length is open; upstream tracked fences without checking for it.
- `scripts/prompt-file` refuses a template whose `text` block never closes, and its header says that the controller does not paste the template because the subagent reads the file.
- `references/owner-gates.md` and the implementer template say how an unforeseen gate in a task without steps resumes: a `Done: ...; continue with: ...` line in place of the start-step line, and "the work that remains" in place of "the steps after the gate".
- Task reviewer template: COVERED also covers a line pinned by a mandated check of the brief, naming the step. Implementer template: the Acceptance item may name the step of a mandated check, and a "Dictated Text and States" paragraph says a sentence reworded by a ruling replaces the brief's. SKILL.md: that reworded sentence is the one exception to exact values appearing only in the brief.
- SKILL.md: the dispatch's requirement line introduces the brief as "your requirements, with the exact values to use verbatim" (the prompt file is the one read first), the final review's template goes out as a file, the Review Focus parenthesis speaks of what no task's acceptance lines cover, and each dispatch of the example workflow names its prompt file. `references/owner-gates.md`: the pre-gate step names the report by the brief, and a task without a gate is recovered from `git log` by the subject or the commit steps its plan gives.
- `references/owner-gates.md`: an unforeseen gate raised by a partial apply inside a gated task gets its post-gate brief "with the start-step line", named so that it cannot be read as the line for a task without steps.

### `plugins/build/skills/execute`

- Renamed `executing-plans` to `execute`.
- Description rewritten to say what the skill does and when to use it.
- Skill references remapped: `superpowers:writing-plans` to `build:plan`, `superpowers:subagent-driven-development` to `build:delegate`, `superpowers:test-driven-development` to `practice:tdd`, `superpowers:systematic-debugging` to `practice:debug`, `superpowers:verification-before-completion` to `practice:verify`, `superpowers:requesting-code-review` to `review:request`, `superpowers:finishing-a-development-branch` to `build:finish`; the pointer to `../using-superpowers/references/` dropped.
- Workspace moved from `<repo-root>/.superpowers/sdd/<plan-basename>/` to `<repo-root>/tmp/build/<plan-slug>/`, resolved by `../delegate/scripts/workspace` (upstream `../subagent-driven-development/scripts/sdd-workspace`). Ledger first line changed from the upstream `# SDD ledger` header (which carried an em dash) to `# build ledger: plan <path>`. Added that `tmp/` may be emptied at any time, recover from `git log`.
- Setup: the worktree paragraph pointing at `superpowers:using-git-worktrees` replaced by an `### Isolated workspace` section (ask once whether to use a worktree, prefer the harness's native tool, fall back to `git worktree add .worktrees/<branch>` with `.worktrees/` git-ignored, never install packages, never start on main without consent, the plan is already committed on the branch) with a `#### With devenv` subsection (entering the worktree and running `devenv shell` gives the same environment).
- Spec pointer: "If the plan names a Spec" became "the `## Design` section of the same file, otherwise the external spec the plan header points at".
- Stop conditions: the four upstream stops plus a fifth, a check or hook that could only be passed by disabling, skipping or weakening it, with the rule never to do so. "Only the four stops" became "only the five stops"; one rationalization row added for skipping a failing hook.
- Continuous execution names the user's two review gates (the plan before, the finished branch after).
- Commit rule made explicit in "Work the steps": one commit per task on the feature branch, Conventional Commits, one concern per commit, never on main.
- Final review: the cross-plugin file reference `[code-reviewer.md](../requesting-code-review/code-reviewer.md)` replaced by invoking `review:request`, which holds the template; inputs listed as the review package path, the plan and its Design section, the Review Focus verbatim and the ledger's `Ruling:` lines. Without a subagent tool: invoke `review:request` and apply its brief yourself, ledger `Final review: self-review (no subagent tool)`.
- Ledger line formats use semicolons where upstream used em dashes: `Ruling: <what>; <why>; <cost>`, `Final: fixed <finding>; <test> RED→GREEN, suite <N>/<N>`.
- Finish: added that the user reads the finished branch starting from "Rulings I made" and "Deferred minors"; ends by calling the Skill tool for `build:finish`.
- Scripts `task-start` and `task-done`: now call `../../delegate/scripts/task-brief` and `../../delegate/scripts/workspace` (upstream `../../subagent-driven-development/scripts/{task-brief,sdd-workspace}`), through `bash` rather than direct exec as the delegate scripts do; the ledger header changed as above; comments reworded without dashes. Exec bits kept.
- The process graph: `systematic-debugging` node renamed to `practice:debug`, the final node to "Invoke build:finish", the review node names `review:request`, "spec" became "design" in the setup node; edge labels lose their dashes.
- Example workflow: paths rewritten to `docs/plans/2026-09-23-recovery.md`, workspace to `../delegate/scripts/workspace`, the opening announcement dropped, "typo" became "misspells", `npm test` kept as an example with a sentence saying so, the closing line invokes `build:finish`.
- "Announce at start" line dropped. "your human partner" and "your partner" replaced by "the user" throughout. Rationalization table: "Only the four stops" and "your partner decides" reworded.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; bold labels end in a full stop instead of a colon; the sub-skill callouts say "call the Skill tool for".
- `task-start` takes the bare path that `task-brief` now prints; upstream parsed the `wrote <path>: N lines` line with sed.
- The brief carries the plan's Global Constraints, and "Take the task" says so.
- Final review: the reviewer also gets the ledger's `State:` lines (facts that superseded the plan, the spec or an inventory), which the executor ledgers as `State: <fact>` when it learns them.
- Finish: the workspace is handed to `build:finish` instead of deleted (upstream deleted it here), so the ledger's deferred minors reach `build:finish`; the graph node, the Finish section and the example say so, and a rationalization row was added. "The only place" the rulings reach the user became "where".
- The second gate is the pull request that `build:finish` opens, and the final message's two lists go into its description. The stop list's side effects are the ones the user's standing instructions leave to them (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish); pushing the feature branch and opening its pull request are left to `build:finish`, which asks before the push unless the user's standing instructions cover it.
- Owner gates, which are not upstream: continuous execution names the review gates and the owner gates; the five stops run the protocol in `../delegate/references/owner-gates.md`; the process graph branches on a gated task; `task-start` passes `--part pre-gate|post-gate` to `task-brief`; setup restores a paused run's ledger; an `## Owner gates` section says how the inline executor differs (it runs both parts, dispatches the evidence reviewer, and records the completion with `task-done`); the final message lists the owner gates; three rationalization rows; the stop list names the owner gates the plan declares beside the five stops.
- Owner gates: `Task N post-gate: started` is ledgered before any post-gate step runs.
- `workspace`, `execution-status restore` and `review-package` are named as `<this skill's directory>/../delegate/scripts/...` and run from the repository root, where "from this skill's directory" was read as changing into it.
- `task-done` records a passing test command that prints nothing, with `(no output)` as the last line, where upstream exited 1 under `pipefail` and recorded nothing.
- `## Owner gates`: the evidence review passes the task's ledger lines and the hash of its record commit in place of the report files, which the inline executor does not write.
- Setup follows Resuming in `../delegate/references/owner-gates.md` for a plan that declares owner gates or holds an Execution status, whether or not the run paused, where it restored only a paused run's ledger; recovering a lost workspace points gated tasks at the same section; the resume rule and its gated-task exception are one sentence; `PLAN_FILE` is the plan's path relative to the repository root in the ledger's identity line and every script call; the rationalization row says a run-time approval lapses when the session that received it ends before the post-gate part starts.
- `## Owner gates`: the evidence review's findings are screened before any fix, and one whose fix needs another live action becomes an unforeseen gate.
- `## Owner gates`: the post-gate part of an unforeseen gate starts with `task-start PLAN_FILE N` without `--part`, at the step after the stop.
- Finish: the "Owner gates" list holds one entry per gate, and the paragraph says `build:finish` puts three lists in the pull request description and reads the owner gates from their record commits.
- Owner gates, which are not upstream: the record commit body starts with the line `Owner gate: <id>`.
- Owner gates, which are not upstream: an unforeseen gate's post-gate part keeps the task's original BASE for the evidence-review package and `task-done`; the lapsed-approval row names the unforeseen-gate exception.
- Owner gates, which are not upstream: after `task-done` records a gated task's completion, the task's temporary files are removed, as the protocol's step 8 says.
- Final review: a final finding that conflicts with the plan or the owner gate protocol, or that needs no change to the branch, is ruled on and ledgered; the fix pass takes the rest.
- Owner gates, which are not upstream: `../delegate/references/owner-gates.md` is read at setup, and Resuming runs also on a fresh start with no ledger, because a lost workspace looks like one: its restore runs before the ledger is read, its other steps once the ledger exists, created first with its identity line when none exists and no Execution status recreates it.
- State walk, which is not upstream: in the final review's fix pass, a fix to protocol text (text that names states and the events between them, or a rule that holds across steps, recognized by a sentence that is read on more than one path) gets one, with the states and paths listed before the edit, each read again after it, and the walk ledgered as `Final: walked <finding>; ...`; one rationalization row.
- Final review: the reviewer reads the template's prompt from a file that `../delegate/scripts/prompt-file` writes to the workspace, and the dispatch names that file and fills each placeholder by its name; the template is never pasted, condensed or reworded, and the evidence reviewer's template goes out the same way.
- Scripts `task-start` and `task-done`: take the task's label from `../../delegate/scripts/task-brief --label`; `task-start` prints it as a third line, `label: <label>`; `task-done` ledgers `<label>: complete (...)`, names the log `task-N-slug-tests.log` and its failure message by the label, and stops before the test command when `task-brief` refuses the task.
- `task-done`: the log name is built from the label only, so a space in the workspace path stays as it is.
- Tasks are named by their label (`Task 3 rate-limiter`, or `Task 3` without a slug) in every ledger line format; `task-start` prints the label and `task-done` writes the completion line under it.
- The inline executor is the implementer: the core principle says the plan carries the decisions and the tests and the code are the executor's; "Work the steps" became "Work the task" (a failing test per acceptance line, then the code; dictated text placed word for word; a States block walked and ledgered as `<label>: walked <state>: <outcome>; ...`; steps only for a task with an owner gate or a mandated check, or from a plan written before plans had tasks without steps); the completion contract speaks of acceptance lines, `task-done` takes the command that runs the task's own test files, and the process graph, two rationalization rows and the example workflow follow. "A fully specified plan makes inline execution transcription plus testing" became a statement that the plan is written for a skilled developer, so inline execution needs a session model of the mid tier or above.
- The post-gate part of an unforeseen gate in a task without steps starts at the acceptance lines that remain, where it would start at the step after the stop.
- The evidence review's template goes out as a file, as "Final review" says; the Review Focus parenthesis speaks of what no task's acceptance lines cover; the TDD sentence speaks of tasks, not steps; the example workflow names Task 1 by its label.

### `plugins/build/skills/finish`

- Renamed `finishing-a-development-branch` to `finish`.
- Description rewritten to say what the skill does and when to use it.
- Step 1 "Verify Tests" became "Run the full check": the repository's full check (every lint and every test), with `npm test`, `cargo test`, `pytest` and `go test ./...` named as examples of a test command rather than the assumption; a `### With devenv` subsection says the full check is `devenv test`. The failure message says "Full check failing".
- New Step 2 "Remove the plan": when the branch carries `docs/plans/YYYY-MM-DD-<slug>.md`, remove it in a final commit `chore: remove the plan for <slug>`, with one sentence on why (history holds the work, decisions were recorded as decisions). Under `### With the Lyngon documents`: check the Design section for a decision that passes the admission test and is not yet in `docs/decisions/`, and record it first via `discover:domain-model`. The brief asked for a `####` heading here; markdownlint MD001 forbids skipping from `##` to `####`, so it is `###`.
- Later steps renumbered (detect environment 3, base branch 4, options 5, execute 6, cleanup 7) and the cross-references in the bash comment and the prose updated.
- Option 1 runs the full check on the merged result (`<full check>` placeholder instead of `<test command>`).
- Option 2: the pull request description opens with the "Rulings I made" and "Deferred minors" lists from the executor's final message, or a short summary when no executor produced the branch; "pull/merge request" reads "pull request (or merge request)".
- Menu wording: "Keep the branch as-is" became "as it is"; "Create PR" became "Create a pull request" in the quick reference.
- Cleanup: "Superpowers created this worktree" became "the executor created this worktree"; the refused-removal example file kinds no longer mention "uncommitted plans".
- Rationalization table: one row added about leaving the plan file; "Tests passed earlier" became "The check passed earlier"; "your human partner" replaced by "the user".
- "Announce at start" line dropped; the core principle gained "remove the plan".
- Placeholders in prose use square brackets (`[your best guess]`, `[name]`, `[path]`) where upstream used angle brackets outside code, because markdownlint reads those as inline HTML; placeholders inside fenced blocks keep angle brackets.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; tables given leading and trailing pipes.
- Step 2 resolves the plan workspace (`tmp/build/<slug>/`, through `build:delegate`'s `workspace` script) before removing the plan, since the executors now hand it over instead of deleting it. Under `### With the Lyngon documents`: list the executor's deferred minors and the ledger's `minor (deferred)` and parked lines, ask the user which go to `docs/TODO.md`, write those with today's date and commit them with the plan removal; a branch without a ledger says so and moves on.
- Step 7 renamed "Clean up the plan workspace and the worktree": it removes the plan workspace first, on the merge and discard paths only; options 2 and 3 keep it because the work has not landed. The cross-references in options 1 and discard name both, and the quick reference's "Keep worktree" column became "Keep worktree and plan workspace".
- Rationalization table: a row added for deferred minors left in the executor's message.
- Option 2 ends the report with the landing steps for after the forge merges the pull request (switch to the base, `git pull --ff-only`, remove the plan workspace and the worktree, delete the branch, in an order git accepts), and a note on `-D` after a squash or rebase merge. The quick reference gained a row for them, and the rationalization table a row for the local base branch catching up on its own.
- The integration menu is gone. Step 5 pushes the branch and opens the pull request without asking, as the user's standing instructions say; merging locally, keeping the branch and discarding moved to Step 6, "Other outcomes, on request". Without a remote it reports and keeps the branch, without a forge CLI it hands over the creation link, and an existing pull request gets its description updated. The description lists what changed and why, decisions for the user, the executor's rulings and deferred minors with a link to the plan at the parent of the plan-removal commit, unfixed review findings, and the verification. Step 3's table says how the branch is pushed instead of which menu to show; Step 4 takes the base without asking for a pull request and asks only before a local merge. The description, the overview, Step 1's last line, Step 7's opening, the quick reference and the rationalization table follow, with rows for asking before the push and for amending a pushed commit.
- Step 2 collects the deferred findings instead of asking about them; they go into the pull request description, and Step 5's report asks which go to `docs/TODO.md` after the pull request is open, committing the chosen ones as a new commit; Step 6's outcomes ask the same before Step 7 removes the workspace. Step 5 runs the full check again when Step 2 added commits. The rationalization table gained a row against asking before the push, and the base-branch row applies to a local merge.
- Step 5 asks once, right before the push, unless the user's standing instructions cover pushing and opening a pull request; a `### With the Lyngon workflow` section at its end says that `conventions:engineering`'s do. The ask has a template, and its answer covers the branch's later pushes. The description and the rationalization rows about asking before the push and about the TODO question follow.
- Owner gates, which are not upstream: the owner gates list finds each record commit by the line `Owner gate: <id>` in its body, where it took any commit whose body named a gate ID, and the lookup runs over the range from the merge base to `HEAD`, so an earlier plan's record commit on the base branch never matches.
- Every command is a plain command with its values written out, and the overview says to run each on its own: Step 2 runs `workspace` without capturing its output and takes the merge base with its own `git merge-base` command, Step 3 prints the git directory and the common git directory with `git rev-parse --path-format=absolute` (git 2.31 or later), Steps 6 and 7 find the main repository root with `git worktree list`, and `<plan workspace>`, `<merge base>`, `<worktree path>` and `<main repository root>` stand where upstream and the earlier patches used `$PLAN_WORKSPACE`, `$(git merge-base ...)`, `$GIT_DIR`, `$GIT_COMMON`, `$WORKTREE_PATH` and `$MAIN_ROOT`. A Claude Code session isolated in a worktree (2.1.285) refused each of the earlier forms, as "too complex to verify that it stays inside the worktree", and no shell variable lasts between shell calls. Step 6 says that such a session hands the local merge, the discard and Step 7 to the user, since the same harness refuses git in the main repository.
- The pull request is the commit it lands as. Step 5 gives it a title in Conventional Commits form and writes the description under seven second-level headings (`## Why`, `## Decisions`, `## What changed`, `## Scope`, `## Blast radius`, `## Verified`, `## Not verified`), where it listed six items in order. "Decisions for you", the executor's rulings and the link to the plan sit under Decisions; the deferred minors, the unfixed review findings and the owner gates under Scope, which ends with the line `Met on the way:` and the issues and pull requests the work filed or opened for a problem it met, or `nothing`. A list too long for the description goes into a comment on the pull request. A `### With the Lyngon baseline` section at the end of the step runs `check-pull-request` on the title and the description before the pull request is opened and after every change to either.

### `plugins/build/skills/plan`

- Renamed `writing-plans` to `plan`.
- Description rewritten to say what the skill does and when to use it, keeping "write the plan" and "plan the implementation" as triggers and naming `discover:approach` as the home of design questions.
- Dropped `plan-document-reviewer-prompt.md`: the upstream SKILL.md no longer uses it, self-review replaced the subagent.
- Dropped the "Announce at start" line and the "Context" line about `superpowers:using-git-worktrees` (the executor decides on a worktree at setup).
- Plan location changed from `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (a whole file, user preference overriding) to a `## Plan` section appended to `docs/plans/YYYY-MM-DD-<slug>.md`, the file `discover:approach` starts with its `## Design` section; a new "Where the plan lives" section explains this, the case where the design came from elsewhere (create the file with a `## Design` section pointing at the spec), and that `build:finish` removes the file when the branch is done.
- Plan header changed from an H1 `# [Feature Name] Implementation Plan` to the `## Plan` heading, with `Global Constraints` and `Review Focus` as H3 under it; the header keeps the upstream heading names so executors and reviewers find them. The "For agentic workers" line names `build:delegate` (recommended) or `build:execute`. The `Spec:` field points at the `## Design` section of the same file or the external spec it points at.
- Task structure: example paths rewritten to `<package>/src/...` and `<package>/tests/...` with a sentence saying the repository's layout and declared test command decide; step titles reworded ("Run the test to verify it fails"). Added the commit rule: one commit per task on the feature branch, Conventional Commits, one concern per commit, more commits only when the plan says so, never on main.
- "File structure" gained a bullet that the repository's layout decides where files go.
- Execution handoff: the two options renamed to Delegate (`build:delegate`) and Inline (`build:execute`); the recommendation sentence kept; added that the plan is committed on the feature branch (creating the branch when still on main, because nothing is committed on main without consent), that the user reviews the plan now and the finished branch later and is not asked between tasks, and the sentence "You will not be asked again until the branch is finished" in the handoff text. The handoff messages are fenced `text` blocks instead of bold paragraphs. "Subagent-driven" and "Native" became "Delegate" and "Inline".
- Added a `## With the Lyngon documents` section: decisions that pass the admission test go to `docs/decisions/` via `discover:domain-model`, settled terms to `CONCEPTS.md`, and the plan is not a steering document.
- Self-review rewritten as a numbered list with the same four checks (two more were added later, see below).
- "your human partner" replaced by "the user" throughout.
- Reflowed to one sentence per line; every em dash removed; headings in sentence case; the "No placeholders" list reworded without dashes; `pytest` example command kept as an illustration.
- Added a pointer to `WORKFLOW.md`, the shared flow document, symlinked into this skill from the devkit's `shared/`.
- Added a `## Checks and commands` section after the task structure: every check the plan mandates is shown failing without its property and passing with it, with the `pipefail` and `grep -q` false negative as the example; a command a person runs by hand is POSIX sh or runs through `bash -c`, with a pointer to `conventions:shell` when the conventions plugin is installed. "No placeholders" gained "a check without a control".
- Self-review gained two checks: 5, every mandated check proven both ways; 6, every block of dictated prose checked against the repository's recorded decisions, the gates and rules in its agent instructions, and the design's and plan's own findings. `## With the Lyngon documents` names the decision records, the rule files under `.claude/rules/` and `CONCEPTS.md` for that check.
- The execution handoff names the pull request that `build:finish` opens as the second gate, and says the rulings are presented in its description; between the gates the executor asks the user nothing.
- Owner gates, which are not upstream: a `### Owner Gates` index in the plan header; an `## Owner gates` section with the gate step, its fields and its rules; every task ends with at least one commit; a "No placeholders" item and self-review item 7 for gates; the handoff asks for pre-approvals by ID and records them in the index before invoking the executor.
- Owner gates, which are not upstream: a step title says "owner gate" only in a marker, and the executor refuses any other step title that says it and a task the index names without its marker.
- The pointer to `WORKFLOW.md` names the user's two review gates; the first handoff template's clause about the owner gates not pre-approved is left out when the plan declares none; self-review item 7 says "an action an executor must stop for" where it said "stop-list action", a term the skill never defined.
- Owner gates, which are not upstream: the executor removes a gated task's temporary files once the evidence review is clean, not before; a character a hook rejects in a pre-approval, or a `|` that would break the index table, is replaced by its plain form.
- Owner gates, which are not upstream: the gate record commit body starts with the line `Owner gate: <id>`.

- Departs from upstream's rule of complete code in every step: a task has Intent, Acceptance and Commit blocks and no steps, and holds no test code or implementation, because the implementer writes the tests and the code. The "Bite-sized granularity" section is removed, "Overview" is rewritten around what the implementer cannot know or must not decide, and "No placeholders" is rewritten to match.
- Added dictated text (a task's blocks of text placed word for word, located by file, section and anchor, with a States block for protocol text), tasks with steps only for an owner gate or a mandated check, a slug in every task heading and step, and the rule that tasks and steps are referred to by label.
- Self-review rewritten to nine items: the line test, a size check and a check of dictated text against its states were added, and the type-consistency check also covers references to tasks and steps.
- Execution handoff: a recommendation rule (`build:execute` for about five tasks or fewer without an owner gate the agent performs, `build:delegate` otherwise), the plan's size and longest task in both messages, and an inline-review warning for an owner gate the agent performs.
- The Owner Gates index example row names its task by its label (``Task 6 `state-bucket` ``).
- Self-review item 8 (dictated text) also checks that every dictated block's fence is longer than any fence inside it.
- The execution handoff messages name the longest task by its label.

### `plugins/discover/skills/approach`

Every patch to this skill is in one list, in the order the patches were made, under the same destination in [mattpocock.md](mattpocock.md).
That list names what was adapted from `skills/brainstorming`, and what was changed in it or left out of it.

### `plugins/practice/skills/debug`

- Renamed `systematic-debugging` to `debug`.
- Rewrote the description to say what the skill does (root cause before any fix: read the error, reproduce, check recent changes, gather evidence, one hypothesis, minimal test, then a failing test first) and when to use it (any bug, failing test, unexpected behaviour, build failure or performance problem, before proposing a fix), with "the integration test started failing after the refactor" as the example and "adding a feature" as a non-trigger.
- Moved `root-cause-tracing.md`, `defense-in-depth.md`, `condition-based-waiting.md` and `condition-based-waiting-example.ts` into `references/`, and `find-polluter.sh` into `scripts/`; every link and mention updated to the new paths.
- Dropped `test-academic.md`, `test-pressure-1.md`, `test-pressure-2.md`, `test-pressure-3.md` and `CREATION-LOG.md`: the upstream author's own eval scenarios and creation notes, not material for the agent.
- Phase 4 invokes `practice:tdd` (was `superpowers:test-driven-development`) and `practice:verify` (was `superpowers:verification-before-completion`).
- The heading "your human partner's Signals You're Doing It Wrong" became "Signals from the user that you are doing it wrong"; "Discuss with your human partner" became "Discuss with the user"; "Manager wants it fixed NOW" became "The user wants it fixed now".
- The user signal "Ultra-think this" became "Think harder about this", because "ultrathink" is a keyword of one harness.
- "See Phase 4.5" became "Phase 4, step 5", since there is no such heading.
- The Phase 1 multi-layer bash example is kept as an illustration of layer-by-layer evidence, introduced as "a signing pipeline with four layers".
- `scripts/find-polluter.sh` rewritten: the test command is a third argument (`find-polluter.sh <path-to-check> <test-glob> <test-command>`) instead of a hard-coded `npm test`, run through `bash -c` so the command can carry flags; `set -euo pipefail`; test files are read into an array line by line instead of word-splitting `$TEST_FILES`; `find` limited to `-type f`; a missing match list and a pre-existing polluted path exit 2 up front instead of skipping each file with a warning; usage errors go to stderr; the emoji in the output are gone. The exec bit is kept. The usage text and the call in `root-cause-tracing.md` show the third argument.
- `references/condition-based-waiting-example.ts`: the three-line header comment naming the Lace project and the session date is replaced by two neutral lines; the rest is verbatim, including the `Lace*` type names, since it is an example nothing runs.
- Dropped the "Real-World Impact" sections of `root-cause-tracing.md` and `condition-based-waiting.md` (session date, test counts, pass rates) and the "1847 tests" figures in `defense-in-depth.md`, replaced by "the whole suite passed"; the "Real Example" and "Example from Session" walk-throughs are kept as "Example".
- `condition-based-waiting.md` says the example file is an example to adapt, not code that anything runs; the "Common mistakes" pseudo-list became a real list.
- `root-cause-tracing.md` names `npm test` as "the repository's test command (here `npm test`)" before the capture command; the call-chain listing uses `->` instead of the Unicode arrow.
- Removed every em dash and en dash; "≠" in prose became words; the `≥`/`<` comparisons in Phase 4 are spelled out ("3 or more", "fewer than 3").
- Headings renamed to sentence case with no trailing punctuation; "Red Flags - STOP and Follow Process" became "Red flags: stop and follow the process".
- Whole-line bold pseudo-headings ("**BEFORE attempting ANY fix:**", "**Find the pattern before fixing:**", "**Scientific method:**", "**Fix the root cause, not the symptom:**") became plain sentences (markdownlint MD036); the iron law and evidence blocks are fenced as `text`.
- The supporting-techniques list now links into `references/` and mentions `scripts/find-polluter.sh`.
- Spelling normalised to "behaviour" in prose (code and graph labels untouched).
- Reflowed every prose paragraph to one sentence per line; blank lines added around lists and fences; continuation lines under numbered steps indented to the step text.

### `plugins/practice/skills/tdd`

- Renamed `test-driven-development` to `tdd`.
- Rewrote the description to say what the skill does (failing test first, watch it fail, minimal code, watch it pass, refactor, delete code written before its test) and when to use it (any feature, bug fix, refactor or behaviour change, before production code), with "add a retry to the HTTP client" as the example and renames, prose edits and configuration named as non-triggers.
- Moved `writing-good-tests.md` to `references/writing-good-tests.md` and updated the link in SKILL.md.
- Replaced the `<Good>` and `<Bad>` inline HTML blocks with `**Good:**` and `**Bad:**` labelled paragraphs that carry the upstream caption; the code is unchanged.
- Replaced the whole-line bold step labels in the bug-fix example (`**RED**`, `**GREEN**`, ...) with level-3 headings, because markdownlint MD036 rejects emphasis used as a heading.
- Replaced the bare `npm test path/to/test.test.ts` instruction in Verify RED and Verify GREEN with "run the repository's test command for that file, for example:" followed by the upstream command; the bug-fix example says the same before its `$ npm test` output.
- "Other tests means the project's suite" now reads "the repository's whole suite"; the example commands (`pytest`, `npm test`, `cargo test`) stay examples of "whatever the repository uses".
- "Exceptions (ask your human partner)" became "Exceptions (ask the user)"; "Ask your human partner" in the "when stuck" table and "your human partner's permission" in the final rule became "the user".
- Added one sentence under "When to use": a mechanical rename with no behaviour change needs no new test, the existing tests prove it changed nothing; and the "Refactoring" bullet now says the tests exist before you start and stay green. Reason: the description must not fire on "rename this variable" while refactoring stays in the "always" list.
- The debugging integration now invokes `practice:debug` before the failing test is written; added a short "Verification" section that invokes `practice:verify` before claiming the work is done (upstream referenced neither skill from this file).
- Removed every em dash and en dash (rationalization table, warning signs, principle paragraphs); replaced "≠" in prose with words.
- Renamed headings to sentence case and removed trailing punctuation from them; "Red Flags - STOP and Start Over" became "Red flags: stop and start over".
- The iron law and final rule code blocks are fenced as `text` (markdownlint MD040); the final rule uses `->` instead of the Unicode arrow.
- "not typos" became "not a spelling mistake" in Verify RED and the checklist, because `typos` is a baseline term for the prerequisite validator.
- In `writing-good-tests.md`: "your human partner's correction" and "your human partner's question" became plain rules ("Ask: are we testing the behaviour of a mock?", "Ask: do we need to be using a mock here?"); the sentence naming `superpowers:writing-skills` became "Documents that instruct agents are tested by the consuming agent's behaviour"; the gate function blocks use `->` and are fenced as `text`; the arrow-and-outcome sentence "Wrong answers → test utility" became a sentence.
- Spelling normalised to "behaviour" in prose (code identifiers untouched).
- Reflowed every prose paragraph to one sentence per line; blank lines added around lists and fences.
- Dropped the upstream "Announce at start" convention (none in this file) and every reference to superpowers paths.

### `plugins/practice/skills/verify`

- Renamed `verification-before-completion` to `verify`.
- Rewrote the description to say what the skill does (run the command that proves a claim and read its output before claiming that something works, passes, is fixed or is done) and when to use it (before any completion or success claim, before committing, opening a pull request, handing over or moving on), keeping the upstream phrase "evidence before assertions, always" and naming a claim-free question as a non-trigger.
- Added the row "Full check green" to the claims table: requires the repository's full check run in this session with exit 0; a green test run, a green linter or a run from an earlier session is not sufficient.
- Added a `## With devenv` section saying the full check is `devenv test`, which runs every git hook on every file plus the repository's tests, and that "Full check green" means that command ran in this session and exited 0.
- "VCS diff" became "the version control diff" in the claims table and the agent delegation pattern.
- "About to commit/push/PR" became "About to commit, push or open a pull request"; "PR creation" became "opening a pull request".
- Removed the "≠" comparisons from the rationalization table ("Confidence is not evidence", "A linter is not a compiler", "Exhaustion is not an excuse").
- Headings renamed to sentence case with no trailing punctuation; "Red Flags - STOP" became "Red flags: stop".
- The iron law, gate function and key pattern blocks are fenced as `text`; the arrows in the patterns are `->`; the ✅ and ❌ markers are kept.
- Reflowed to one sentence per line; blank lines added around lists and fences.

### `plugins/review/skills/receive`

- Renamed `receiving-code-review` to `receive`; the H1 is "Receive a code review" (upstream: "Code Review Reception").
- Rewrote the description to say what the skill does and when to use it, naming the user, a reviewer subagent and an external reviewer as sources and keeping upstream's "before implementing suggestions, especially if unclear or technically questionable" trigger.
- "your human partner" became "the user" throughout, including the example transcripts ("The user: 'Fix 1-6'").
- The two "your human partner's rule:" quotes became plain rules in the skill's voice: "Rule: external feedback gets checked carefully, not implemented on trust." and "Rule: the reviewer and you both answer to the user; a feature nobody needs is not added because a reviewer suggested it."
- "(explicit instruction-file violation)" became "(a phrase many instruction files forbid)".
- "Simple fixes (typos, imports)" became "Simple fixes (spelling mistakes, imports)"; the original word is a baseline hook name the prerequisite validator rejects.
- Added a "From a reviewer subagent" source between the user and external reviewers: treated as external (verify first), with the instruction to open each file and line reference before anything else and to push back with the reference when a finding does not match the code.
- Dropped the "Overview" heading; its one sentence now opens the body.
- Sentence-cased the headings; replaced the hyphen-as-dash connectors ("STOP - do not", "Good catch - ") with colons; removed the em dashes; reflowed prose to one sentence per line; gave every fenced block the `text` language; the three-sentence core principle is three lines.
- Expanded contractions and telegraphic phrasing in the rule blocks and examples ("Need legacy for backward compat" became "The legacy path is needed for backward compatibility") without changing the rules.
- "top-level PR comment" became "top-level pull request comment".
- Kept the response pattern, forbidden responses, unclear-feedback rule, YAGNI check, implementation order, push-back rules, correction wording, common mistakes, real examples and the GitHub thread-replies section.

### `plugins/review/skills/request`

- Renamed `requesting-code-review` to `request`; the H1 is "Request a code review".
- Rewrote the description to say what the skill does and when to use it, naming `build:delegate`, `build:execute`, "before merging" and "get this reviewed before I merge" as triggers, and "there is code to review" to keep design discussions out.
- Moved `code-reviewer.md` to `references/code-reviewer.md` and updated both links.
- "After each task in subagent-driven development" became "After each task in `build:delegate`"; added "At the end of `build:execute`" to the mandatory list.
- "Push back if reviewer is wrong" and the "If reviewer wrong" list now point to `review:receive` for evaluating and answering the findings.
- Unified the placeholder syntax on `{NAME}`: upstream uses `{NAME}` in SKILL.md and `[NAME]` in the template.
- Added the optional placeholders `{REVIEW_PACKAGE}` (the file that `build:delegate`'s `review-package` script prints, so the reviewer reads one file), `{REVIEW_FOCUS}` (the plan's Review Focus section verbatim, with "check each of these deliberately and report on each one") and `{RULINGS}` (the ledger's `Ruling:` lines, with "weigh these calls; disagree where warranted"), each as its own template section, plus the rule to leave out a section with nothing to fill it.
- Added `model: {MODEL}` to the template header and one sentence in SKILL.md to specify the model explicitly, the most capable tier for a whole-branch review, matching how the build executors dispatch it.
- Replaced `Subagent (general-purpose):` with the neutral "Dispatch a subagent with:".
- Replaced `git worktree add /tmp/review-[SHA] [SHA]` with `git worktree add <temporary directory> <sha>`, so the template names no fixed path.
- "The executor rules on each line" became "The requester rules on each line": the skill is also used outside the build executors.
- Added a "Declined to judge" heading to the reviewer's output format and to the example output, so the list the template asks for has a place in the report.
- Added step 3's rule to rule on every "Declined to judge" line, and a note under step 1 that `HEAD~1` covers one commit only, so multi-commit tasks and branches use the recorded base or the merge base.
- Added a third rationalization row ("It's a small change, review is overkill").
- Rewrote the example with a neutral plan path (`docs/plans/2026-09-23-deployment.md`) and a recorded base commit instead of grepping `git log` for a task name.
- Sentence-cased the headings; removed the em dashes; reflowed prose to one sentence per line; gave every fenced block a language and wrapped the template in a four-backtick fence so its inner `bash` fence renders.
- Lower-cased the severity labels in the output format headings ("Critical (must fix)") and removed "Senior Code Reviewer" capitalization; no change of meaning.
- Added the optional `{STATE_CHANGES}` placeholder and its "State changes since the inputs were written" section after the rulings: the facts that superseded the plan, the spec or an inventory, so the reviewer judges against the world as it is. Listed in both placeholder lists and in the rule for leaving out empty sections.
- The review package section says the package carries every commit's full message, and the git range block adds `git log`, so the commit messages can be checked with or without a package.
- Dropped nothing else; the read-only rule, the no-subagents rule, the spec-as-vision section, the check lists, the calibration, the critical rules, the rationalization table, the red flags and the example output are kept.
- The description and the mandatory list name opening a pull request where they named merging, and step 3 sends Minor findings that nobody fixes to the pull request description.
- The whole-branch reviewer checks every task's acceptance lines and states: a paragraph under "Requirements or plan", the review focus described as the failure modes that no task's acceptance lines cover, and an output section "Acceptance lines and states" that is left out for a bounded change or a plan without Acceptance blocks.

## Review notes

### `plugins/build/skills/delegate`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Three bash scripts write only under `tmp/build/` in the repository and read git; no network, no credentials, no hooks, no tool restrictions, no encoded content. Subagent prompts contain a "You do not dispatch subagents" contract, which limits rather than widens execution. The continuous-execution rule is the chosen workflow, stop conditions remain.
- Quality: description rewritten. Trigger check: "execute the plan with subagents" and a plan handoff that chose delegation trigger; "help me debug this test" does not. Body is the longest in the set (568 lines upstream, 499 here with the templates in `references/`). Dependencies: bash, git, a subagent tool, `practice` and `review` skills. Scope stated. Agent-neutral.
- Fit: paths patched as for `execute`; cross-plugin file reference to the reviewer template replaced by invoking `review:request`; worktree section folded; no package installs; commit rule per task. Does not write devkit-owned files. Overlap: `build:execute` is the inline alternative; both are wanted, they share the workspace.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: `workspace` adopts any marker-less directory under `tmp/build/` whose name matches the plan slug, so a directory created by hand with that name becomes the plan's workspace; harmless in practice, kept as upstream.
- The scripts have no file extension, so the prerequisite validator does not scan them; they contain no prerequisite terms anyway.

### `plugins/build/skills/execute`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Two bash scripts that read the plan, run the task's test command as given by the executor, and write under the workspace in the repository; no network, no credentials, no hooks, no tool restrictions, no encoded content. The "Continuous execution" and "Rulings, not stalls" rules instruct the agent not to ask between tasks; that is the workflow the user chose (two review gates) and not an override of user instructions, and the stop conditions remain.
- Quality: description rewritten. Trigger check: "execute this plan inline" triggers; "implement this feature" without a plan does not (it goes to `discover:approach` and `build:plan`). Body long (373 lines upstream, 320 here) but a workflow skill that runs once per plan; no references needed. Dependencies stated: bash, git, `build:delegate` scripts, `practice` and `review` skills. Scope stated. Agent-neutral (harness features named generically).
- Fit: `.superpowers/sdd/` patched to `tmp/build/`; `docs/superpowers/plans/` to `docs/plans/`; worktree skill folded into a section without package installs; test commands generic with `devenv test` under a conditional heading; commit rule per task on a branch, never on main. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: `task-done` renders the test command for the ledger line and quotes arguments containing spaces or shell metacharacters; an argument containing a single quote is still rendered unquoted. Cosmetic, ledger only.
- The scripts have no file extension, so the prerequisite validator does not scan them; they contain no prerequisite terms anyway.

### `plugins/build/skills/finish`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Runs git merge, push and worktree removal only after the user picks a menu option; discard needs the typed word; no `--force` on its own; no network beyond `git push` on request; no credentials, hooks, scripts or encoded content.
- Quality: description rewritten. Trigger check: "the plan is done, wrap up the branch" triggers; "commit this" does not. Body 225 lines upstream, 244 here; proportionate. Dependencies: git, optionally a forge CLI. Scope stated.
- Fit: test suite wording generic with `devenv test` conditional; plan-file removal step added per the plan-location decision; decision record check under a documents heading. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: removing the plan (Step 2) happens after the full check (Step 1) and adds a commit; the check is not re-run, since deleting a Markdown file cannot change the tests, but a hook that lints Markdown links would still run on that commit through the normal commit hooks.
- 2026-09-29: pushing and opening a pull request no longer wait for a menu choice (the decision record `planned-work-is-reviewed-at-two-gates` and the standing instructions in `conventions:engineering`); merging, force-pushing and discarding still wait for the user.
- Owner gates, which are not upstream: Step 2 recreates a paused run's ledger from the plan's `## Execution status` with `../delegate/scripts/execution-status restore` and collects the ledger's `Gate` lines; the description gains an "Owner gates" list; one rationalization row.
- Owner gates, which are not upstream: Step 2 runs `execution-status restore` whenever the plan holds an Execution status, since it keeps a longer ledger, where it ran only without a `progress.md`; the "Owner gates" list comes from the record commits in `git log` since the merge base, one entry per gate with its answer or pre-approval and the record commit's hash, where it came from the ledger's `Gate` lines.

### `plugins/build/skills/plan`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. No network access, no credential reads, no scripts, no hooks, no tool restrictions, no instruction override, no encoded content, writes only the plan file in the repository.
- Quality: description rewritten to state what and when. Trigger check: "the design is settled, write the implementation plan" triggers; "fix this typo" and "which database should we use" do not. Body 192 lines upstream, 233 here after reflow; proportionate, no references needed. No runtime dependencies. Scope stated (before touching code; after a spec). Agent-neutral.
- Fit: upstream wrote plans to `docs/superpowers/plans/` (patched to `docs/plans/` with the shared design file), committed per step (patched to per task), and named superpowers executors (remapped). Does not write devkit-owned files. Overlap: none in the devkit; `discover:approach` produces the design this consumes.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: the plan is committed by this skill on the feature branch (creating the branch when on main) rather than left uncommitted for the executor, because a worktree created at execution time would not see an uncommitted file in the main checkout. Upstream never says who commits the plan.

### `plugins/discover/skills/approach`

2026-09-23: the brainstorming text was reviewed against `shared/SKILL-REVIEW.md` before merging; pure prompt text, no scripts; its visual companion (a Node server that also fetches a logo from an external host) was left out.
Its `spec-document-reviewer-prompt.md` (a prompt for a reviewing subagent) was also left out; the self-review step replaces it.

### `plugins/practice/skills/debug`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. One bash script that runs the given test command per test file and checks for a path; no network, credentials, hooks, tool restrictions, overrides or encoded content. The test command is user input executed through `bash -c`, by design: the script exists to run it. The TypeScript file is an example, never executed.
- Quality: description rewritten. Trigger check: "the integration test started failing after the refactor" triggers; "add pagination to the list endpoint" does not. Body 283 lines upstream, techniques in `references/`. Dependencies: bash for the script. Scope stated. Agent-neutral.
- Fit: the upstream eval scenarios and creation log dropped; script test command made an argument; references moved; "human partner" voice replaced. The Phase 1 example uses macOS `security` and `codesign`; kept as an illustration only. Does not write devkit-owned files. Overlap: the engineering convention's one line on reproducing bugs; this is the procedure, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.

### `plugins/practice/skills/tdd`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text with code examples; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content.
- Quality: description rewritten to state what and when. Trigger check: "add a retry to the HTTP client" triggers; "rename this variable" and "tidy the README" do not. Body 330 lines upstream plus a 198-line reference; the reference moved to `references/`. No runtime dependencies. Exceptions stated. Agent-neutral; examples are TypeScript with jest and vitest, kept as illustrations.
- Fit: inline HTML tags removed; test command generic; "human partner" voice replaced; the delete rule kept deliberately: upstream's strictness (code written before its test is deleted, exceptions only with the user's permission) is the point of the skill, and softening it would leave the rationalization table answering a rule that no longer exists. Does not write devkit-owned files. Overlap: the `conventions` plugin's engineering skill states the testing rules in three lines; this is the procedure behind them, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.

### `plugins/practice/skills/verify`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content.
- Quality: description rewritten. Trigger check: about to say "all tests pass" triggers; "what does this function do" does not. Body 120 lines upstream, proportionate. No dependencies. Scope obvious. Agent-neutral.
- Fit: full-check row added with a conditional `devenv test` line. Does not write devkit-owned files. Overlap: the engineering convention's "report faithfully" line; this is the procedure, both stay.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.

### `plugins/review/skills/receive`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content. The `gh api` line is an example of replying in a thread and runs only when the agent chooses to.
- Quality: description rewritten. Trigger check: "the reviewer says to remove the legacy path" triggers; "write a review of this PR" does not. Body 205 lines, proportionate. Dependencies: optionally the GitHub CLI. Scope stated. Agent-neutral.
- Fit: the author's personal rules rewritten as plain rules; a "reviewer subagent" source added for the build plugin; the word that trips the baseline term list replaced. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.

### `plugins/review/skills/request`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Prompt text and a subagent template; the template makes the reviewer read-only on the checkout and forbids it from dispatching further subagents. No network, credentials, scripts, hooks, tool restrictions, overrides or encoded content.
- Quality: description rewritten. Trigger check: "get this reviewed before I merge" triggers; "review this design with me" does not. Body 95 lines plus a 198-line template moved to `references/`. Dependencies: git, a subagent tool. Scope stated. Agent-neutral.
- Fit: superpowers references remapped; review-focus and rulings placeholders added for the build plugin; the temporary worktree path made neutral. Does not write devkit-owned files. Overlap: Claude Code's own review command exists but takes no plan context; this template is what `build` needs, and it is what a user asks for when they say "get this reviewed".
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
- Noticed while rewriting: the upstream template asks for a "Declined to judge" list but its output format has no heading for it, so a reviewer following the format literally has nowhere to put the list; the heading was added. Upstream's example computes the base with `git log --oneline | grep "Task 1"`, which breaks on multi-commit tasks; the executors record the base instead, and the example now says so.
