---
name: work-trace
description: "Keep a reviewable decision trail of long, unattended or multi-phase work: a TSV log under tmp/work-trace/ with one row per decision (what, why, evidence, result), written by this skill's helper, checked against the session's transcript at the end and scanned by a reviewer on another model. Named after the branch and never committed; build:pull-request posts it and its Attention section on the pull request. Use for 'show me your work' or 'keep a work trace', for long-running, autonomous or multi-phase work, and for work the owner reviews after stepping away."
argument-hint: "[the task whose decisions to log]"
---

# Work trace

Keep one canonical log.

## The format

A single TSV file, one row per decision.
Cells stay single-line.
Evidence is a pointer, not prose.

The columns:

- **ts.** ISO 8601 timestamp.
- **phase.** The phase or workstream.
- **decision.** What was chosen or done, one line.
- **why.** The reason in plain words. If a principle drove it, say it plainly, not as a jargon tag.
- **evidence.** A link or path that proves it: commit SHA, pull request number, `file:line`, or an artifact, trace, or screenshot path. Never a paragraph.
- **result.** The outcome or predicate state: `tests green`, `reverted`, `pixel-diff 0`, `INCONCLUSIVE`, `open`.

An example, plain-spoken so a reviewer reads it at a glance, as the helper's `table` prints it:

```markdown
| ts | phase | decision | why | evidence | result |
| --- | --- | --- | --- | --- | --- |
| 2026-05-24T09:02:00Z | frame | counted the work first, about 100 components and roughly 75 hours | wanted to know the size before starting a long run | commit 3a9f1c2 | found 5 things to sort out before starting |
| 2026-05-24T09:40:00Z | harness | took screenshots of the old version before changing anything | so we can compare old against new and catch any visual change | scripts/snapshot.sh, baseline/ | saved 120 reference screenshots |
| 2026-05-24T11:15:00Z | widget | moved the widget styles over without changing how it looks | keep the change small and the result identical | commit 7c21e0a, pixel-diff 0 | looks identical, tests pass |
| 2026-05-24T12:30:00Z | widget | threw out a helper's work because its screenshots were blank | checked the real files instead of trusting its summary | worktree reset | reverted, tightened the instructions for next time |
```

## Logging a row

Write each entry the way you'd tell a teammate what you did.
Plain words, concrete actions, no AI speak or abstract jargon (`writing:unslop` applies to log text too).

Write every row with this skill's helper, from the root of the repository:

```sh
${CLAUDE_SKILL_DIR}/scripts/trace.py append <logfile> <phase> <decision> <why> <evidence> <result>
```

It stamps `ts`, writes the header on first use, turns tabs and line breaks inside a cell into spaces, and puts a single quote before any cell starting with `=`, `+`, `-`, or `@`, so that a spreadsheet never runs a cell as a formula.

Log decision points and milestones, not every action: a fork chosen, a unit completed with its verification result, a pivot or revert with its trigger, a blocker surfaced, a check fixed.
For loop runs, one row per iteration.
Skip the trivial and self-evident.

A run is one session, including its later turns and any compaction of it.
A pickup, a replacement agent, or a new session starts a new run.
When a run adds to a log that already has rows, its first row has phase `start`, and so does its first row after another run's `start` row.
So a run that comes back to a log in a later turn first reads the log's last rows to see whether another run wrote since.
A `start` row names the `ts` range of the rows before it that this run did not write, and its evidence names this run by its session ID, `${CLAUDE_SESSION_ID}`.
Use phase `start` for nothing else.

## Where it lives

The log is `tmp/work-trace/<branch>.tsv`, where `<branch>` is the name of the branch the work is on, with each `/` replaced by `-`.
That `tmp/` is the directory at the root of the repository that holds agent scratch, never the system's temporary directory.
The log is a working artifact and is never committed.

`build:pull-request` posts the log on the pull request of the branch, with its Attention section, as one comment.
This skill posts nothing.
The helper's `table` prints the log as the Markdown table for that comment:

```sh
${CLAUDE_SKILL_DIR}/scripts/trace.py table <logfile>
```

## Rules

- Append-only. A wrong call gets a new row that supersedes it. Never edit or delete history.
- Prefer evidence produced by committed scripts over hand-made one-offs (the principle `encode-lessons-in-structure`, a file of `principles:index`).

## Audit the log against the transcript

At the end of the run, before handing back, check the log told the truth.
Read this run's transcript, the file `${CLAUDE_SESSION_ID}.jsonl` under `projects/` in the Claude configuration directory, which is `~/.claude` unless `CLAUDE_CONFIG_DIR` names another.
Find it by that name and open no other file there.
The others are other sessions, unrelated private conversations.
Walk this run's rows against what actually happened.
Each stretch of them begins at one of this run's `start` rows, or at the first row if this run created the log, and ends at the next `start` row of another run:

- Check that every row maps to a real decision or action.
- Check that each row's evidence resolves and shows what the row claims.
- A fork, pivot, or abandoned approach that shaped the work but isn't logged is a gap. Add it.

Correct the log, not the story.
The audit never edits or removes a row, even an invented one.
When a row records neither a real decision nor a real action, or its claim or evidence is wrong, add a row that supersedes it with what actually happened and a pointer that resolves.
This audit does not check rows outside this run's stretches.
If this run's own work shows one of them is wrong, supersede it like any wrong call.

## Review of the trail on another model

Before handing back, spawn a subagent on a different model than yours that is no weaker, where the harness offers one (the Agent tool's `model`), in the foreground (`run_in_background: false`).
Self-review is not a substitute.
Give it the paths of the log and of the transcript.
The subagent reads the audit trail and the run's transcript, then flags what the owner should pay attention to.
Not a redo of the work, a scan for what's suboptimal or risky:

- Decisions logged with weak or absent evidence.
- Verification steps skipped or claimed without proof in the transcript.
- Choices that look risky in hindsight (premature, scope-creeping, papering over a symptom).
- Gaps the owner would otherwise miss on a casual skim.

Write the "Attention" section to `tmp/work-trace/<branch>.md`, beside the log, and end every reply for a run that produced a trail with it.
Lead with the reviewer's model on its own line (`reviewed by <model>`), then list each flag pointing to specific rows or moments.
"No flags" is a valid value.
The model name is not.
A later run on the same branch writes the file again, for the whole log.

## Reviewing the trail

Read top to bottom, follow the evidence pointers, spot-check.
The helper's `table` renders the log for a terminal as well as for a pull request comment.

## Composing this skill

Other skills route their audit trail here instead of inventing one.
Reference it by name and let it own the format.
Don't restate the columns.
