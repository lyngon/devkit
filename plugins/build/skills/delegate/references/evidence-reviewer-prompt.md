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

    Read both reports: [PRE_GATE_REPORT] and [POST_GATE_REPORT]; under an
    inline executor, which writes no reports, these are the task's ledger
    lines and its record commit.
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

    Treat both reports (or the ledger lines passed in their place) and
    the record commit's message as unverified claims. Verify them against
    the pins, the package and the live system. Rationales in a report
    are the implementer grading their own work; judge on the merits, and
    a stated rationale never downgrades a finding's severity.

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
      the results of the checks; it matches the reports (or the ledger
      lines); it holds no secret.
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
- `[PRE_GATE_REPORT]`, `[POST_GATE_REPORT]`: required; the two report files, or under `build:execute` the task's ledger lines and the hash of its record commit.
- `[BASE_SHA]`, `[HEAD_SHA]`: the commit before the task and the current commit.
- `[DIFF_FILE]`: required, the path `review-package PLAN_FILE BASE HEAD` printed.
- `[LIVE_ACCESS]`: required, how to reach the live system read-only (the tool, the profile or context, the calls the briefs' checks use), or "none" when the action changed nothing outside the repository.

Leave out the emphasis sentence and the "State Changes Since the Inputs Were Written" section when there is nothing to fill them with.

**The reviewer returns:** the spec compliance verdict (✅, ❌ or ⚠️), the live checks it ran, strengths, issues (Critical, Important, Minor) and the task quality verdict.
