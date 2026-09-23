---
name: debug
description: >-
  Find the root cause before proposing any fix: read the error, reproduce it, check recent
  changes, gather evidence layer by layer, form one hypothesis, test it minimally, then fix
  it with a failing test first. Use for any bug, failing test, unexpected behaviour, build
  failure or performance problem, before proposing a fix (for example "the integration test
  started failing after the refactor"). Not for adding a feature.
---

# Systematic debugging

## Overview

**Core principle:** always find the root cause before attempting a fix.
Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The iron law

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you have not completed Phase 1, you cannot propose a fix.

## When to use

Use for any technical issue:

- Test failures
- Bugs in production
- Unexpected behaviour
- Performance problems
- Build failures
- Integration issues

**Use this especially when:**

- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You have already tried several fixes
- The previous fix did not work
- You do not fully understand the issue

**Do not skip it when:**

- The issue seems simple (simple bugs have root causes too)
- You are in a hurry (rushing guarantees rework)
- The user wants it fixed now (systematic is faster than thrashing)

## The four phases

Complete each phase before proceeding to the next.

### Phase 1: root cause investigation

Before attempting any fix:

1. **Read the error messages carefully**
   - Do not skip past errors or warnings; they often contain the exact solution
   - Read stack traces completely
   - Note line numbers, file paths and error codes

2. **Reproduce consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - Does it happen every time?
   - Not reproducible?
     Gather more data; do not guess.

3. **Check recent changes**
   - What changed that could cause this?
   - Git diff, recent commits
   - New dependencies, config changes
   - Environmental differences

4. **Gather evidence in multi-component systems**

   When the system has several components (CI, then build, then signing; API, then service, then database), add diagnostic instrumentation before proposing a fix:

   ```text
   For EACH component boundary:
     - Log what data enters the component
     - Log what data exits the component
     - Verify environment and config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze the evidence to identify the failing component
   THEN investigate that specific component
   ```

   Example, a signing pipeline with four layers:

   ```bash
   # Layer 1: workflow
   echo "=== Secrets available in workflow: ==="
   echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

   # Layer 2: build script
   echo "=== Env vars in build script: ==="
   env | grep IDENTITY || echo "IDENTITY not in environment"

   # Layer 3: signing script
   echo "=== Keychain state: ==="
   security list-keychains
   security find-identity -v

   # Layer 4: the signing itself
   codesign --sign "$IDENTITY" --verbose=4 "$APP"
   ```

   This reveals which layer fails (secrets reach the workflow, the workflow does not pass them to the build).

5. **Trace the data flow**

   When the error is deep in the call stack, read [root-cause-tracing.md](references/root-cause-tracing.md) for the complete backward tracing technique.

   Quick version:
   - Where does the bad value originate?
   - What called this with the bad value?
   - Keep tracing up until you find the source
   - Fix at the source, not at the symptom

### Phase 2: pattern analysis

Find the pattern before fixing:

1. **Find working examples**
   - Locate similar working code in the same codebase
   - What works that is similar to what is broken?

2. **Compare against references**
   - If implementing a pattern, read the reference implementation completely
   - Do not skim; read every line
   - Understand the pattern fully before applying it

3. **Identify differences**
   - What is different between working and broken?
   - List every difference, however small
   - Do not assume "that cannot matter"

4. **Understand dependencies**
   - What other components does this need?
   - What settings, config, environment?
   - What assumptions does it make?

### Phase 3: hypothesis and testing

Scientific method:

1. **Form a single hypothesis**
   - State it clearly: "I think X is the root cause because Y"
   - Write it down
   - Be specific, not vague

2. **Test minimally**
   - Make the smallest possible change that tests the hypothesis
   - One variable at a time
   - Do not fix several things at once

3. **Verify before continuing**
   - Did it work?
     Yes: go to Phase 4.
   - Did it not work?
     Form a new hypothesis.
   - Do not add more fixes on top

4. **When you do not know**
   - Say "I don't understand X"
   - Do not pretend to know
   - Ask for help
   - Research more

### Phase 4: implementation

Fix the root cause, not the symptom:

1. **Create a failing test case**
   - The simplest possible reproduction
   - An automated test if possible
   - A one-off test script if there is no framework
   - You must have it before fixing
   - Invoke `practice:tdd` for writing a proper failing test

2. **Implement a single fix**
   - Address the root cause identified
   - One change at a time
   - No "while I'm here" improvements
   - No bundled refactoring

3. **Verify the fix**
   - Does the test pass now?
   - Are no other tests broken?
   - Is the issue actually resolved?
   - Invoke `practice:verify` before claiming success

4. **If the fix does not work**
   - Stop
   - Count: how many fixes have you tried?
   - Fewer than 3: return to Phase 1 and re-analyze with the new information
   - **3 or more: stop and question the architecture (step 5 below)**
   - Do not attempt fix number 4 without an architectural discussion

5. **If 3 or more fixes failed: question the architecture**

   The pattern that indicates an architectural problem:
   - Each fix reveals new shared state, coupling or a problem in a different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   Stop and question the fundamentals:
   - Is this pattern fundamentally sound?
   - Are we sticking with it through sheer inertia?
   - Should we refactor the architecture instead of continuing to fix symptoms?

   **Discuss with the user before attempting more fixes.**

   This is not a failed hypothesis; this is a wrong architecture.

## Red flags: stop and follow the process

If you catch yourself thinking:

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add several changes, run the tests"
- "Skip the test, I'll verify manually"
- "It's probably X, let me fix that"
- "I don't fully understand, but this might work"
- "The pattern says X, but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing the data flow
- **"One more fix attempt" (when you have already tried 2 or more)**
- **Each fix reveals a new problem in a different place**

**All of these mean: stop. Return to Phase 1.**

**3 or more fixes failed?** Question the architecture (Phase 4, step 5).

## Signals from the user that you are doing it wrong

Watch for these redirections:

- "Is that not happening?": you assumed without verifying
- "Will it show us...?": you should have added evidence gathering
- "Stop guessing": you are proposing fixes without understanding
- "Think harder about this": question the fundamentals, not just the symptoms
- "We're stuck?" (frustrated): your approach is not working

When you see these: stop.
Return to Phase 1.

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "The issue is simple, I don't need the process" | Simple issues have root causes too. The process is fast for simple bugs. |
| "Emergency, no time for the process" | Systematic debugging is faster than guess-and-check thrashing. |
| "Just try this first, then investigate" | The first fix sets the pattern. Do it right from the start. |
| "I'll write the test after confirming the fix works" | Untested fixes do not stick. Test first proves it. |
| "Several fixes at once saves time" | You cannot isolate what worked. It causes new bugs. |
| "The reference is too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms is not understanding the root cause. |
| "One more fix attempt" (after 2 or more failures) | 3 or more failures means an architectural problem. Question the pattern; do not fix again. |

## Quick reference

| Phase | Key activities | Success criteria |
| --- | --- | --- |
| **1. Root cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form a theory, test minimally | Confirmed, or a new hypothesis |
| **4. Implementation** | Create a test, fix, verify | Bug resolved, tests pass |

## When the process reveals "no root cause"

If systematic investigation reveals that the issue is truly environmental, timing-dependent or external:

1. You have completed the process.
2. Document what you investigated.
3. Implement appropriate handling (retry, timeout, error message).
4. Add monitoring or logging for future investigation.

**But:** 95% of "no root cause" cases are incomplete investigation.

## Supporting techniques

These techniques are part of systematic debugging and live in `references/` next to this file:

- [root-cause-tracing.md](references/root-cause-tracing.md): trace a bug backward through the call stack to its original trigger, with `scripts/find-polluter.sh` for finding the test that leaves state behind
- [defense-in-depth.md](references/defense-in-depth.md): add validation at several layers after finding the root cause
- [condition-based-waiting.md](references/condition-based-waiting.md): replace arbitrary timeouts with condition polling
