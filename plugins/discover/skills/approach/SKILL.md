---
name: approach
description: >-
  Settle a design before building. Classifies the work as a spike, a bounded change or an
  architectural change, interviews the user relentlessly on the architectural path, writes
  CONCEPTS.md terms and ADRs as they settle, and gates implementation on the user's approval
  of the design. Use before building anything with more than one reasonable design, and when
  the user asks to design something, plan an approach, think something through, or says
  "grill me". Not for tossing ideas around without commitment; that is discover:brainstorm.
argument-hint: "[--no-docs]"
---

# Approach

Turn a request into a design the user has approved, in the smallest form the work needs.
A spike ends in an answer, a bounded change in a short design in chat, an architectural change in a design file that the build plugin turns into a plan.
Whatever the path, nothing is built until the user has said yes to what that path produces.

## Classify first

Before the first question, classify the request and say the classification aloud ("this looks bounded, so I will present a short design here rather than write a design file") so the user can override it.

- **Spike**: a feasibility question ("can we", "is it possible", "quick and dirty is fine") whose output is an answer, not code you keep.
  Present the question and the probe in two or three sentences, get a nod, then investigate as cheaply as correctness allows.
  Report the findings as a recommendation; anything built is labelled throwaway.
- **Bounded**: a well-scoped change to a flow that already exists in the repository, such as a new flag, a small endpoint or a one-file fix.
  Bounded measures the repository, not your familiarity with the kind of app; when there is no existing flow to change, the work is not bounded.
  Ask the clarifying questions that matter in one round, in the format of `discover:interview`.
  Present a short design in chat: approach, files touched, testing.
  Stop and wait for an explicit yes.
  Then implement through the normal workflow, with `practice:tdd` when the practice plugin is installed.
  When the review and build plugins are installed, `review:request` before merging and `build:finish` to integrate the branch.
  No plan file.
- **Architectural**: new subsystems, restructuring how components fit together, or interfaces others depend on.
  Follow the architectural path below.

When in doubt between two paths, take the heavier one.
The ratchet is one-way: hidden complexity discovered mid-task upgrades the path (stop, say so, step up), and nothing downgrades.

## The gate

No implementation action before the selected path's approval: no product code, no scaffolding, no dependency added, no implementation skill invoked.
Read-only exploration of the repository is allowed at any time.
A reply approves the stage actually presented.
Approval of an idea is not approval of a design; approval of a design is not approval of a plan.
Resume at the earliest incomplete stage; never turn one approval into permission to skip the rest of the path.

## Architectural path

1. Call the Skill tool for `discover:interview` and `discover:domain-model`.
   With `--no-docs`, call only `discover:interview`: sharpen the design without writing `CONCEPTS.md` entries or ADRs.
2. Explore the repository first: files, documents, recent commits.
3. Before asking detailed questions, check whether the request spans several independent subsystems.
   If it does, decompose first: name the pieces, how they relate and in which order to build them, then take the first piece through the rest of this path.
   Each piece gets its own design, plan and implementation cycle.
4. Run the interview rounds until the frontier is empty.
   Terms and decisions go into `CONCEPTS.md` and `docs/adr/` as they settle, through `discover:domain-model`.
5. Propose two or three approaches with trade-offs, lead with your recommendation and say why, and settle on one with the user.
   Remove every feature the goal does not need from every approach.
6. Write the settled design to `docs/plans/YYYY-MM-DD-<slug>.md` under a `## Design` heading with the sections goal, approach, components, data flow, error handling, testing and out of scope.
   Scale each section to its complexity: a few sentences when it is straightforward, a few paragraphs when it is not.
   The file is transient: purpose, working rules, terms and decisions belong in the Lyngon documents, and the build plugin removes the file when the work is finished.
7. Self-review the file with fresh eyes and fix what you find inline, without another round of review:
   - Placeholders: "TBD", "TODO", empty sections, vague requirements.
   - Internal consistency: sections that contradict each other, an approach that does not match the components.
   - Scope: focused enough for a single plan, or in need of decomposition.
   - Ambiguity: a requirement that can be read two ways; pick one and make it explicit.

   When the writing plugin is installed, pass the design through `writing:unslop` before the user sees it.
8. Ask the user to review the file and stop: "Design written to `<path>`. Please review it and tell me what to change before the plan is written."
   Make the requested changes, self-review again and ask again.
9. When the user approves the file and the build plugin is installed, invoke `build:plan`.
   Otherwise hand the file over; the design is the deliverable.
   Invoke no other skill.

## Design for isolation and clarity

- Break the system into units that each have one purpose, communicate through defined interfaces, and can be understood and tested on their own.
- For each unit you should be able to answer what it does, how it is used and what it depends on.
- If a unit cannot be understood without reading its internals, or its internals cannot change without breaking consumers, the boundaries need work.
- Smaller units are also easier for an agent to work on: reasoning is better over code that fits in context at once, and edits are more reliable in focused files.
  A file that has grown large is usually doing too much.

## Working in existing codebases

- Explore the current structure before proposing changes, and follow the existing patterns.
- Where existing code has problems that affect the work (a file grown too large, unclear boundaries, tangled responsibilities), include targeted improvements in the design, the way a good developer improves the code they work in.
- Do not propose unrelated refactoring; stay with what serves the goal.

## Red flags

| Thought | Reality |
| --- | --- |
| "This is too simple to need a design" | Follow the selected path: a bounded change gets a short design in chat, an architectural change gets the design file. |
| "I will call it bounded and skip the design file" | Reaching for a label to skip work is the doubt; take the heavier path. |
| "The design is obvious, I will start while they read it" | The gate is the approval, not the length of the design. Present, then stop until you hear yes. |
| "I know this kind of app, so it is bounded" | Bounded measures the repository, not your familiarity. A new subsystem has no existing flow, so it is architectural. |
| "The spike works, so I will keep the code" | A spike's output is an answer. Keeping the code is a new request; classify it. |
| "It grew, but I am almost done" | Hidden complexity upgrades the path mid-task. Stop and say so. |

To toss ideas around without any of this, use `discover:brainstorm`.
The flow between this skill, the build plugin and the practice skills is in [WORKFLOW.md](WORKFLOW.md).
