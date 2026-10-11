---
name: index
description: The index of Lyngon's principles, one line per principle saying when it applies and what it demands, each with a file under references/. Invoke before work that takes judgment, such as a design choice, a refactor, a bug fix, a test, a measurement, a script, a document or a question to the owner; then read the file of each principle that applies.
---

# Principles

A principle is a named, binding statement that takes judgment to apply.
Each line below names one principle, says when it applies and gives its rule.
The line tells you that a principle applies, and only its file tells you how to apply it.
Read `references/<name>.md`, next to this file, in full for every principle you apply.

The origin in parentheses says who wrote the principle: pstack, vendored with the patches in `UPSTREAM.md`, or Lyngon.
A repository's own principles are not here.
They are its rule files under `.claude/rules/`.

## Core

- **laziness-protocol** (pstack). Refactoring, sizing a diff, or tempted to add abstractions, layers, or signal threading. Bias toward deletion and the smallest change that solves the problem.
- **foundational-thinking** (pstack). Before writing logic: choosing core types and data structures, sequencing scaffold and feature work, asking what concurrent actors share. Get the data structures right so that downstream code becomes obvious.
- **redesign-from-first-principles** (pstack). Integrating a new requirement into an existing design. Redesign as if the requirement had been a foundational assumption from day one, instead of bolting it on.
- **attack-the-premise** (pstack). Two or more fixes that share one premise have failed the same gate. Take a census of which actors hold the imbalance before the next fix, then question the premise instead of writing another fix that assumes it.
- **subtract-before-you-add** (pstack). Sequencing an addition, refactor, or rewrite. Remove dead code, redundant validators, and stub references first, then build on the simpler base.
- **minimize-reader-load** (pstack). Reviewing or shaping code that is hard to trace. Count the layers between question and answer and the hidden state in the reader's head, collapse one-caller wrappers and shrink mutable scope.
- **outcome-oriented-execution** (pstack). Planned rewrites and migrations with explicit phase boundaries. Converge on the target architecture instead of preserving smooth intermediate states with throwaway compatibility code, and keep the breakage inside a branch.
- **experience-first** (pstack). Product, UX, or feature-scope tradeoffs. Choose user delight over implementation convenience, and ship fewer polished features over more rough ones.
- **exhaust-the-design-space** (pstack). A novel interaction or architectural decision with no precedent in the codebase. Build 2-3 competing prototypes and compare them side by side before committing.
- **build-the-lever** (pstack). Any non-trivial work: edits, migrations, analyses, checks. Build the tool that does it or proves it (codemod, script, generator) instead of working by hand, because the tool is the artifact a reviewer can rerun.

## Architecture

- **model-the-domain** (pstack). Writing stateful logic, or code that branches a lot or repeats a shape assumption across files. Encode the domain in a structure (a state machine, a typed model, a table or registry, a reducer) instead of scattered conditionals.
- **boundary-discipline** (pstack). Wiring validation, error handling, or framework adapters. Concentrate guards at system boundaries (CLI, config, network, external APIs), trust internal types and keep business logic in pure functions.
- **type-system-discipline** (pstack). Designing types or reviewing a function signature in any statically typed language. Make illegal states unrepresentable, brand semantic primitives, parse external data at boundaries and never lie to the compiler.
- **make-operations-idempotent** (pstack). Designing commands, lifecycle steps, or processing loops that run amid crashes, restarts, and retries. Converge to the same end state regardless of partial prior runs.
- **migrate-callers-then-delete-legacy-apis** (pstack). Introducing a new internal API while old callers still exist. Migrate the callers and delete the old API in the same wave instead of preserving compatibility layers.
- **separate-before-serializing-shared-state** (pstack). Concurrent actors might write to the same file, branch, key, or state object. Eliminate the sharing first, and serialize structurally only when one shared writer is a real invariant.

## Verification

- **prove-it-works** (pstack). After completing a task, before declaring it done. Verify against the real artifact (run the feature, read the actual value, inspect the diff), not a proxy, a self-report, or "it compiles".
- **fix-root-causes** (pstack). Debugging. Reproduce first, ask why until you reach the root cause and fix it there, and resist guards that silence the symptom.
- **sequence-verifiable-units** (pstack). Multi-step work (sweeps, migrations, runs of similar edits) and the order of commits inside a change. Break the work into small units that each end in a state you can check, check each before the next, and order the commits so that the sequence proves itself to a reviewer.
- **test-behavior-not-implementation** (pstack). Writing, changing, or keeping a test. Call the code the way its users do and assert the result they observe against a literal expected value, and rewrite or delete a test that would still pass if every imported function returned nothing.
- **explain-the-number** (pstack). Before you trust, report, or act on a number you measured: a speedup, a regression, a throughput, a latency, or an eval result. Find what limits it, and rule out that it measured something other than the work you think.

## Delegation

- **guard-the-context-window** (pstack). Context is filling up: large outputs, long files, repeated reads, fan-out planning. Route bulk to subagents and keep summaries in the main thread, not raw payloads.
- **never-block-on-the-human** (pstack). Tempted to ask "should I do X?" on reversible work. Proceed and present the result, and ask only before an irreversible action or for a product or preference call that no run can settle.

## Meta

- **encode-lessons-in-structure** (pstack). You catch yourself writing the same instruction a second time, or notice a recurring correction. Encode the rule as a lint, a metadata flag, a runtime check, or a script instead of more text, because a rule without a check is debt.

## Steering

- **record-what-the-code-cannot-show** (Lyngon). About to write prose into the tree, or making a decision the code cannot show. Prose enters only through the admission test, and a decision that passes it is recorded in the same change.
- **the-tree-is-current** (Lyngon). A decision, a plan or a text is superseded, or you are tempted to keep history in a file. The tree holds what is true now, so superseded text is deleted, and git and `discover:why` hold the past.
- **review-results-not-plans** (Lyngon). Tempted to wait for approval of requirements, a specification, a plan or tasks. Nothing waits for approval by default, and a gate exists if and only if the owner asked for it explicitly, where the agent then stops.
- **fix-debt-in-its-own-change** (Lyngon). You find debt while doing other work. Fix it in the same session in its own change when the fix can be proven, and otherwise file an issue with the evidence.
- **reshape-instead-of-commenting** (Lyngon). About to write a comment that explains a surprise in your own code. Fix the surprise in the code instead.
- **name-things** (Lyngon). Introducing or referring to a decision, a principle, a rule, a task, a step, an option or a question. Give it a name and refer to it by that name, with a three-digit prefix when it is ordered and a bare number only where a tool assigns it.
- **prescribe-proof-not-steps** (Lyngon). Writing anything an agent will follow: a skill, a prompt for a subagent, an issue, a plan. State what must hold and what proof is owed, and give steps only where they are facts the reader cannot derive.
- **use-purpose-built-tools** (Lyngon). Writing a script or a check. Use the tool built for the task, such as jq for JSON, declared through Nix and pinned, with nothing from the ambient PATH, and write highly custom logic as a Python program shipped as source.
