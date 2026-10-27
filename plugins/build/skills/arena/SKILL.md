---
name: arena
description: "Run several candidates at the same task in parallel, score them against a rubric beside a cross-judge on another model, pick the strongest as the base and graft the best parts of the others into it. Use only when the operator asks for it, as in 'arena this' or 'throw it in the arena', or when build:architect sketches a design. Not on your own initiative."
argument-hint: "<the task, and the artifact each candidate produces>"
---

# Arena

Fan out N parallel attempts at the same task.
Read every candidate end to end.
Pick the strongest as the base.
Graft the best ideas from the others into it.
Verify the synthesized result.

The principles this skill names are files of `principles:index`.
Read each one before you apply it.

## Frame

The N candidates will receive the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric. State what success looks like for *this* task, then turn it into 3 to 6 concrete gradeable criteria. The rubric is the picker's tool in "Pick a base". Candidates only see the task.
3. Pick the runners. By default there are two, each on a different model where the harness offers more than one (the Agent tool's `model`), and none on a weaker model than yours. Spawn more when the arena covers multiple design directions. Use the same model for every runner when the work is generation-bound rather than judgment-sensitive.
4. Give each candidate a place of its own, per the principle `separate-before-serializing-shared-state`. A candidate whose artifact is a change to the repository's files works in a git worktree of its own, which the Agent tool's `isolation: "worktree"` gives it where the harness offers it. Every other candidate, a draft or a sketch among them, writes to `tmp/arena/<task>/candidate-<n>/`, and so does one whose harness offers no worktree. That `tmp/` is the directory at the root of the repository that holds agent scratch, never the system's temporary directory.

## Fan out

Spawn all N candidates in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every candidate is back before you go on.
Give each the task, the path to the shared grounding, its own output path, and instructions to produce both the artifact and a short rationale.
When the skill that invoked this one names a prompt for the candidates, as `build:architect` does with its runner prompt, each candidate gets that prompt's text unchanged, with these inputs filled in around it.

Each rationale names the alternatives the candidate considered and what it rejected.

If a candidate fails to produce output, proceed with N-1 and note the dropout in the synthesis note.

## Cross-judge

Once every candidate is back, read each one end to end and score it against the rubric, criterion by criterion, not on holistic feel.
Start the synthesis note, `tmp/arena/<task>/synthesis.md`, with those scores before you start the judge, so that its verdict cannot steer yours.

Then spawn one judge subagent in the foreground (`run_in_background: false`), on a different model than yours that is no weaker, where the harness offers one.
The judge reads and changes nothing.
It sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale.

## Pick a base

Compare your scores with the judge's.
Agreement on the base confirms the pick.
Disagreement means one of you is biased or the rubric was ambiguous.
Read both rationales before deciding.

Pick the base on which candidate a future maintainer can extend most easily without breaking invariants.
Prefer the cleaner boundary or smaller API when two feel tied, per the principle `laziness-protocol`.

Record the pick and the reason in the synthesis note, including the judge's verdict.

## Graft

Walk each losing candidate once more and identify what is worth porting into the base.
The signal is usually one or two things per candidate, not most of it.

Fold each graft in by hand, per the principle `redesign-from-first-principles`.
Don't paste mechanically.
The result has to remain coherent under one mental model.

Record what was grafted, from which candidate, and what was rejected and why.

When N candidates converge on the same shape, that is a strong agreement signal.
Note the convergence in the record and ship the consensus shape.
No graft is needed.
When N candidates wildly diverge, the framing was under-specified.
Frame again and run again rather than averaging the divergence.

## Verify

The synthesized artifact has to hold up under the same scrutiny as any other output, per the principle `prove-it-works`.

If verification surfaces a problem the arena did not catch, either the framing was wrong (frame again and run again) or one candidate caught it and you missed the graft (go back to "Graft").
Don't paper over.

## Outputs

One synthesized artifact.
One short synthesis note, `tmp/arena/<task>/synthesis.md`, naming the base, the grafts (with source candidate), the rejections, the dropouts if any, and the verification result.
The note is scratch and never committed, so give what it says in your reply.

The harness keeps the worktree and the branch of a candidate that changed something, and returns both with its result.
Once the synthesized artifact is verified, remove them, since the synthesis note keeps what was taken from each.
