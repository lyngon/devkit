---
name: verify
description: >-
  Run the command that proves a claim and read its output before claiming that something
  works, passes, is fixed or is done. Use before any completion or success claim ("tests
  pass", "fixed", "done"), before committing, opening a pull request, handing over or moving
  to the next task; evidence before assertions, always. Not needed for a question or a
  statement that makes no claim.
---

# Verification before completion

## Overview

**Core principle:** evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The iron law

```text
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verification command in this message, you cannot claim it passes.

## The gate function

```text
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check the exit code, count the failures
4. VERIFY: Does the output confirm the claim?
   - If NO: State the actual status with evidence
   - If YES: State the claim WITH evidence
5. ONLY THEN: Make the claim

Skipping any step is lying, not verifying
```

## Common failures

| Claim | Requires | Not sufficient |
| --- | --- | --- |
| Tests pass | Test command output: 0 failures | A previous run, "should pass" |
| Linter clean | Linter output: 0 errors | A partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Full check green | The repository's full check, run in this session: exit 0 | A green test run, a green linter, a run from an earlier session |
| Bug fixed | Test of the original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | The version control diff shows the changes | The agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## With devenv

The repository's full check is `devenv test`: it runs every git hook on every file plus the repository's tests.
"Full check green" means that command ran in this session and exited 0.

## Red flags: stop

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit, push or open a pull request without verification
- Trusting an agent's success report
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting the work over
- **Any wording implying success without having run the verification**

## Rationalization prevention

| Excuse | Reality |
| --- | --- |
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence is not evidence |
| "Just this once" | No exceptions |
| "The linter passed" | A linter is not a compiler |
| "The agent said success" | Verify independently |
| "I'm tired" | Exhaustion is not an excuse |
| "A partial check is enough" | Partial proves nothing |
| "Different words, so the rule does not apply" | Spirit over letter |

## Key patterns

**Tests:**

```text
✅ [Run the test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD red-green):**

```text
✅ Write -> Run (pass) -> Revert the fix -> Run (MUST FAIL) -> Restore -> Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**

```text
✅ [Run the build] [See: exit 0] "Build passes"
❌ "The linter passed" (a linter does not check compilation)
```

**Requirements:**

```text
✅ Re-read the plan -> Create a checklist -> Verify each item -> Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**

```text
✅ Agent reports success -> Check the version control diff -> Verify the changes -> Report the actual state
❌ Trust the agent's report
```

## When to apply

**Always before:**

- Any variation of a success or completion claim
- Any expression of satisfaction
- Any positive statement about the state of the work
- Committing, opening a pull request, completing a task
- Moving to the next task
- Delegating to agents

**The rule applies to:**

- Exact phrases
- Paraphrases and synonyms
- Implications of success
- Any communication suggesting completion or correctness
