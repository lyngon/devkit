# Scoped re-review prompt template

Use this template when dispatching a re-review after a fix round.
The re-reviewer verifies the findings were addressed, checks the fix diff for new breakage and, after a fix to protocol text, walks the states the controller listed.
It is not a fresh review; the full review already happened.

**Purpose:** verify each finding from the previous review was addressed, and that the fix itself broke nothing, in the diff or in a state that reads the fixed text.

```text
Dispatch a subagent with:
  description: "Re-review Task N fix round R"
  model: [MODEL, required: choose per the Model selection section of SKILL.md;
         an omitted model silently inherits the session's most expensive one]
  prompt: |
    You are re-reviewing one task's fix round. A previous review produced
    findings; an implementer has attempted to fix them. Your job is to
    verdict each finding, inspect the fix diff and, when this prompt
    has a State Walk section, walk its states, nothing else.

    ## The Task

    Read the task brief: [BRIEF_FILE]

    ## State Changes Since the Inputs Were Written

    [STATE_CHANGES]

    These facts superseded the plan, the spec or an inventory they cite
    after those were written. Where an input and this list disagree, the
    list is current: judge the fix against it.

    ## The Findings Under Verification

    [FINDINGS]

    ## The State Walk

    [WALK_LIST]

    The fix changes text that defines a protocol: states, the events
    that move between them, or a rule that holds across steps. The list
    above names the states and paths that read the changed text, each
    with the outcome it must give there. For each one, read the fixed
    text as an actor in that state would and follow it to its outcome.
    For this check, and only for it, read beyond the fix diff: the
    whole of every file the fix touched and every file the list names.
    A sentence the fix left alone that now contradicts the fixed text
    is breakage of the fix, not an out-of-scope observation. If the
    fixed text is read in a state the list does not name, walk that
    state too.

    ## The Fix

    Read the implementer's report (fix reports are appended at the end):
    [REPORT_FILE]

    **Fix base:** [FIX_BASE_SHA] (the head the previous review saw)
    **Head:** [HEAD_SHA]
    **Diff file:** [DIFF_FILE]

    Read the diff file once. It contains the fix commits with their full
    messages (subject and body), a stat summary, and the fix diff with
    surrounding context. Do not re-run git commands. If the diff file is
    missing, fetch the range yourself: `git log [FIX_BASE_SHA]..[HEAD_SHA]`,
    `git diff --stat [FIX_BASE_SHA]..[HEAD_SHA]` and
    `git diff [FIX_BASE_SHA]..[HEAD_SHA]`.

    Your review is read-only on this checkout. Do not mutate the working
    tree, the index, HEAD, or branch state in any way.

    ## The Live System

    [LIVE_ACCESS]

    Query the live system with read-only calls only: calls that
    describe, list, get or plan without taking effect. Never run a call
    that creates, changes, deletes, locks or unlocks anything, and never
    run the gated action or any command from the brief that takes effect.
    If a check you need would take effect, report it under Out-of-Scope
    Observations instead. Make one focused call per named check, and name
    the check and the call in your report. Whatever the findings are
    about, confirm with one such call that the live system is still in
    the state the evidence review verified: a fix round takes no effect
    outside the repository.

    ## You Do Not Dispatch Subagents

    Do all of this review yourself. Never spawn a subagent to review part
    of the diff, and never spawn another reviewer for a second opinion.
    This process already provides every review seat the work gets; a
    reviewer you spawn duplicates one of them at full cost, and its
    verdict counts for nothing. If the diff feels too large for one
    pass, review it in passes yourself and say so in your report.

    ## Scope

    Your scope is the findings list, the fix diff and, when this prompt
    has a State Walk section, that walk. Verdict every finding.
    Inspect the fix diff for new problems the fix itself introduced. Do NOT
    re-review code the fix did not touch: if you notice an issue entirely
    outside the fix diff, report it under Out-of-Scope Observations; it
    does not block this task and does not extend the loop. A broad
    whole-branch review happens after all tasks are complete.

    ## Tests

    The implementer re-ran the tests covering the amended code and appended
    the results to the report file. Treat the report as unverified claims:
    confirm the fix report names the covering tests and shows their output,
    and verify the claims against the diff. Do not re-run the suite to
    confirm their report. Run a test only when reading the code raises a
    specific doubt that no existing run answers, and then a focused test,
    never a package-wide suite.

    ## Output Format

    Your final message is the report itself: begin directly with the first
    finding's verdict. Every line is a verdict, a finding with file:line,
    or a check you ran; no preamble, no process narration.

    ### Finding Verdicts

    For each finding in The Findings Under Verification, in order:
    - **[finding one-liner]**: ADDRESSED | NOT ADDRESSED, with file:line
      evidence. "Attempted" is not addressed: the specific defect must no
      longer exist.

    ### State Walk

    Only when this prompt has a State Walk section. For each state or
    path in its list, in order, and then for any you added:
    - **[state or path]**: HOLDS | BROKEN, with file:line evidence: the
      outcome the fixed text gives there and, when BROKEN, the sentence
      that gives the wrong outcome or the two sentences that contradict.

    ### New Breakage in the Fix Diff

    Anything the fix itself broke or introduced, with severity
    (Critical/Important/Minor) and file:line. "None" if clean.

    ### Out-of-Scope Observations

    Issues you noticed entirely outside the fix diff. Non-blocking; the
    controller ledgers these for the final review. "None" if none.

    ### Verdict

    **Fix round:** [All findings addressed, no walked state BROKEN, no
    new Critical/Important breakage | Findings or states remain open],
    listing the open findings and the BROKEN states.
```

## Placeholders

- `[MODEL]`: required, the reviewer model per the Model selection section of SKILL.md; scoped re-reviews of small fix diffs take a cheap-to-mid tier, and one that carries a walk list at least a mid-tier model.
- `[BRIEF_FILE]`: the task brief file (the same file the implementer worked from).
- `[STATE_CHANGES]` (optional): the ledger's `State:` lines, the facts that superseded the plan, the spec or an inventory after they were written: manual actions, resources removed, decisions the user took in chat.
- `[FINDINGS]`: the Critical and Important findings and spec gaps from the previous review, copied verbatim, one per bullet.
- `[WALK_LIST]` (only after a fix round or fix wave that had a state walk; leave out the whole "The State Walk" section otherwise): the walk list as the fix dispatch carried it, one state or path per bullet, each with the outcome the fixed text must give there.
- `[REPORT_FILE]`: the implementer's report file (fix reports appended).
- `[FIX_BASE_SHA]`: the head the previous review saw.
- `[HEAD_SHA]`: the current commit.
- `[DIFF_FILE]`: the path `scripts/review-package PLAN_FILE FIX_BASE HEAD` printed.

- `[LIVE_ACCESS]` (required after an evidence-review fix and after a final fix wave that touched a gated task, absent otherwise): how to reach the live system read-only (the tool, the profile or context, the calls the brief's checks use).
  Fill it for every re-review after an evidence-review fix, and for the re-review of a final fix wave that touched a gated task, whatever its findings are about, because the re-reviewer also confirms that the fix round took no effect on the live system; leave out the whole "The Live System" section for any other re-review.

Leave out the "State Changes Since the Inputs Were Written" section when there is nothing to fill it with.

**The re-reviewer returns:** per-finding verdicts (ADDRESSED or NOT ADDRESSED), per-state verdicts (HOLDS or BROKEN) after a state walk, new breakage in the fix diff, out-of-scope observations, and a round verdict.
