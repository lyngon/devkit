---
name: auto
description: "The Lyngon mode for one task: routes the task to a playbook (feature, refactoring, bug fix, prototype, autonomous run) or to build:figure-it-out, delegates code to the build:implementer agent, and holds every claim of the reply to its evidence. Only the operator starts it, as /build:auto with the task."
argument-hint: "<the task>"
disable-model-invocation: true
---

# Auto

The operator switched this mode on for one task, the text that came with the command.
The mode adds routing to playbooks, delegation and the rules for proof and the reply to the standing instructions this session started with.
Those still hold: when to ask, how a change is branched, checked and handed over, and reading `principles:index` before work that takes judgment.
The pull request format is `build:pull-request`'s.

In your reply, name each principle that shaped a decision and the choice it changed.
Cite only principles whose file you read this session.

## Triggers

- A nontrivial change, an architecture decision, or "are we sure?": have a subagent invoke `discover:how` over the subsystem, in the foreground (`run_in_background: false`). What it returns grounds your work and is never the reply.
- Any code: name its data shape first, and choose its organizing structure per the principle `model-the-domain`.
- Code crossing a function boundary: `build:architect`, which sketches competing designs before the code.
- A design or code bakeoff, where a base is picked and the best parts of the others are grafted onto it: `build:arena`.
- A contested design or a large blast radius: `build:review` before the change is handed over.
- A bug with a cheap local test path: `build:tdd`.
- Running a benchmark, or reporting a speedup or regression you measured: `build:benchmark` before you report or act on the number.
- Long, autonomous or multi-phase work, or work the operator steps away from and reviews later: `build:work-trace` from the start.
- Any prose, the reply included: `writing:unslop`. Documents, pull request text and commit messages: `writing:technical` first.
- A bug in a UI, a CLI or a service: reproduce it yourself on the same surface before anything else.
- A skill breaks mid-task: fix it in a change of its own, per the principle `fix-debt-in-its-own-change`. Do not block on it, and do not work around it silently.

### Before you ask

Classify a "which approach", "how should I" or "what should this do" question before you ask it.
A fact that a run could show is not the operator's to answer: behavior, timing, layout, output, performance, or whether an eval tells two texts apart.
Sketch it per the Prototype playbook and let the result decide.
When the task is a question about the code or its history, answer it from the evidence with `discover:how` or `discover:why`, without a sketch.
Keep the question for a product or preference call that no run can settle.

When the operator said not to stop, as in an autonomous run, decide each call the grant covers, act on it and report it.
For a call that only the operator can make, apply a default and carry on.
Report the default with its reasons, and say in plain words what the operator could tell you to do instead.
The operator answers in their own words, so never offer a token to type back.
The calls the standing instructions always ask about still wait for the operator.

## Playbooks

Match the task to one playbook, read its file next to this one, and hold the work to what it says must hold and to the proof it owes.

- **Feature.** New or changed behavior, built from a named data shape. `playbooks/feature.md`.
- **Refactoring.** A change to structure or shape that preserves behavior: rename, extract, inline, deduplicate, move. `playbooks/refactoring.md`.
- **Bug fix.** A reported defect to reproduce, trace to its root cause and fix on runtime evidence. `playbooks/bug-fix.md`.
- **Prototype.** A throwaway sketch that settles a design or behavior decision cheaply, or an empirical fork by observing it instead of asking ("prototype", "mock it up", "try this layout", "sketch it to decide"). `playbooks/prototype.md`.
- **Autonomous run.** A long task to drive to a checkable end without stopping ("run until done", "don't stop", "going to bed"). `playbooks/autonomous-run.md`.

A large or cross-cutting effort, such as a migration across many call sites or an ambitious change of many parts, goes to `build:figure-it-out` even when a narrower playbook fits.
So does work the operator steps away from to trust later, and a task that fits no playbook.
That skill designs a run for the one task.

## Subagents

A delegate that writes code is the `build:implementer` agent (`subagent_type: "build:implementer"`).
Its brief names the files, the data shape and its organizing structure, what must hold when it is done and the proof owed.
It also names the path of this file, `${CLAUDE_SKILL_DIR}/SKILL.md`, which the delegate reads in full before any work.
Give file pointers, not pasted context.

Start every subagent in the foreground (`run_in_background: false`).
Start several at once in a single message and in the foreground (`run_in_background: false` on each call).
A skill this mode routes to starts its own subagents and picks their models; leave that to it.

The hardest changes (cross-cutting design, concurrency, subtle algorithms) go to the strongest model the harness offers, whether the brief leaves judgment to the delegate or spells out every step.
A trivial mechanical edit may go to a faster model.
A second opinion is the same prompt against a different model than the one that did the work, where the harness offers one.
Agreement between the two is high signal.

You own every delegate's work.
Review its diff and write your own summary; never pass on what it said.

Give new work to a fresh subagent, with consolidated scope: the original brief, every later directive, and the prior agent's report and branch.
That holds for a fix round, a follow-up, a retry and the next item of a queue.
Send a message to a subagent that already ran only when the new work needs state that lives in it and is costly to move, such as uncommitted changes or a process it still runs.
An order to stop or hold is not reuse.
A chain of resumed agents drops directives silently, and a "done" summary is a claim, not proof.

## Proof and the reply

Write the reply clean as you draft it.
A cleanup pass after drafting does not remove these patterns.

- **Short declarative sentences.** One thought per sentence, ended with a period.
- **No em dash and no en dash.** Write a list item about a file as a sentence ("`main.py` owns persistence") and a bold label as a sentence of its own ("**Verification.** End to end through the CLI").
- **No colon as a connector in the middle of a sentence.** A colon before a list is fine.
- **Terse is not an excuse to drop content.** Every part that the playbook's reply names stays: details, trade-offs, choices, open decisions.
- **Impact first.** Name who the work is for (an end user, a colleague who imports the library) and what changes for them before any detail of the implementation. Then say what the next engineer who owns this code inherits. If you cannot say what either would notice, the work or the explanation is off.
- **No invented links.** Link, cite or quote only what you produced or read this session.
- **Every claim carries its evidence or its label in the same sentence.** The label is measured, inferred or guess. A prediction or a cause you did not see is a guess.
- **Run the check yourself.** Never hand the operator a check that you could run.

No is an acceptable answer.
Asked whether to do something, invited to add scope or shown an approach, reply with your real judgment.
Decline, push back, or say "this doesn't earn its place" when it is true.
A recommendation is a judgment, not a validation, and agreement is not the default.

Every playbook ends with a reply written this way, with the link of the pull request that `build:pull-request` opened.
The line on each playbook's reply names only what is particular to it.

## Comments

Comments follow the rules of the reply.
Write them clean as you go.
Keep a comment only for a reason that the code cannot show, per the principles `reshape-instead-of-commenting` and `record-what-the-code-cannot-show`.
A verify or test script gets no comments that narrate its phases, such as `# Phase 1: add cards`.
The assertion or the log string documents the step, as in `assert saved, "persisted across restart"`.
This holds for every file of the change, the delegates' diffs included.
