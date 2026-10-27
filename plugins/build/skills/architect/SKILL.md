---
name: architect
description: "Design before code: ground the design in the code the change touches, sketch types, signatures and module boundaries as at least two structurally distinct candidates through build:arena, build against the chosen sketch, and scrap the sketch when building proves it wrong. Use only when the operator asks for it or for a design: 'architect this', 'design this', 'sketch the types first'. Asking for a design counts as asking for this skill. Not on your own initiative for a task that asks for no design."
argument-hint: "<the task to design and then build>"
---

# Architect

Design before implementing.
Sketch types, function signatures, class shapes, and module boundaries with `not implemented` bodies and pseudocode.
Synthesize across multiple model perspectives, then fill in code against the chosen sketch.
If implementation proves the sketch wrong, throw it out and redesign.

The principles this skill names are files of `principles:index`.
Read each one before you apply it.

The sketch and its rationale go into the design file, committed on the branch: the branch's own file under `docs/plans/` when it has one, otherwise a new `docs/plans/YYYY-MM-DD-<slug>.md`.
The build plugin removes the file when the work is finished, as it does every file under `docs/plans/`.

## Ground the problem

Build a real mental model of every system the new code touches.
Have a subagent of its own invoke `discover:how` over the relevant subsystems, started in the foreground (`run_in_background: false`).
What it returns is your grounding, never the reply.

Naming a file isn't grounding.
The grounding is the traced model that `discover:how` prescribes.
If the design redefines ownership or layering, also have a subagent invoke `discover:why` on the existing shape, so the rationale becomes a constraint, not a guess.
When you need both, start the two subagents in a single message and in the foreground (`run_in_background: false` on each call).

Skip this step only when the work is genuinely greenfield with no surrounding system to integrate.

## Sketch

Write the grounding to `tmp/arena/<task>/grounding.md`, in the directory `tmp/` at the root of the repository.
Invoke `build:arena` with the design-sketch task and the path of the grounding.
Pass the part of `references/runner-prompt.md` below its line `---` unchanged as each runner's prompt, with the task, the grounding and the paths filled in around it.
Each candidate produces a design package shaped per `references/rationale-template.md`.

Design it twice.
Require at least two structurally distinct candidates before synthesis, even when the first looks sufficient.
This is the principle `exhaust-the-design-space` made concrete.
Whole-shape alternatives, not point fixes inside one shape.

Screen every candidate against [design-red-flags.md](references/design-red-flags.md) before synthesis.
Assume the next contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles.
Prefer the design where a change that looks right from one file is right for the whole repository.

Compare viable candidates on interface depth.
Prefer the design that hides more complexity behind a smaller, simpler public surface.
A rich interface can keep call chains short by concentrating capability instead of scattering it across layers.

`build:arena` returns one synthesized design package.
The synthesis decision populates the rationale's section "Synthesis decision".
Write the package into the design file, then continue with "Agree" below.

## Agree

By default, go on to implementation with the synthesized design, without stopping.

Stop here when the owner asked for a gate on the design, as in "show me the design before you implement" or "stop and show me before implementing".
Until the owner approves, the sketch lives in the design file only, and nothing else in the repository changes.
Commit the design file on the branch, and stop with one question, the last sentence of your reply: whether the owner approves the design.

After the gate, or at once when there is none, the sketch can ship as its own commit, as the "scaffold first" mode of the principle `foundational-thinking`.
Planned and scoped breakage during fill-in is fine, per the principle `outcome-oriented-execution`.
For adversarial pressure on the design before implementing, when the design is contested or its blast radius is large, invoke `build:review` on the synthesized sketch.
Fold the findings you act on into the sketch and the design file, then continue here.

If the owner or the operator pushes back on the shape, at the gate or after the fact, treat that as grounding evidence.
Ground the problem again and sketch again before writing more code.

## Implement against the sketch

Replace `not implemented` bodies with code, pseudocode with logic.
The synthesized sketch is the contract.

Deviations from the sketch are signal worth surfacing, not friction to absorb silently.
If a function needs a parameter the sketch didn't anticipate, ask whether the sketch was wrong, the requirement was missed, or the implementation is overreaching.

## Scrap when the architecture is wrong

If implementation keeps producing friction the sketch can't absorb, throw the sketch out.
Don't bolt fixes onto a wrong design, per the principles `redesign-from-first-principles` and `fix-root-causes`.

The signal is a *pattern*, not single instances.
Tells:

- The same shape of workaround appearing repeatedly across unrelated code.
- Multiple unrelated edge cases that all need special-case branches.
- Types that need escape hatches (`any`, casts, optional fields always set in practice) to compile.
- The "we need a lock" reflex when the sketch said the state wasn't shared.
- Callers having to know the abstraction's internal rules to use it.
- Two or more independent deviations of the same shape across the implementation.

Use judgment.
A few edge cases don't condemn an architecture.
Some problems are legitimately complex.
Complexity in the data is not complexity in the design.

When you scrap:

1. Have a subagent invoke `discover:how` over what's been built, started in the foreground (`run_in_background: false`), as in "Ground the problem".
2. Redesign as if the new constraints had been day-one assumptions, per `redesign-from-first-principles`.
3. Subtract before adding, per the principle `subtract-before-you-add`. The new sketch should be smaller than the old one before it grows.
4. Return to "Sketch" and invoke `build:arena` again.

## Outputs

The caller's usage is written first and the type sketch derived from it.
One file with new types and signatures for small changes.
Module map plus type definitions for larger work.
The rationale ships alongside in the design file, shaped per `references/rationale-template.md`, including the usage sketch and the synthesis decision.
