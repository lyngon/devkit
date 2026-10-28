---
name: tdd
description: "Fix a bug test first: a focused regression test that fails before the fix and passes after it, committed before the fix and kept, or no test at all rather than a bad one. Use when fixing a bug that a nearby unit, component or integration test can reach cheaply, and when the operator asks for TDD, a failing test or a regression test. Not when the test would need broad harness setup, production-only state or slow end-to-end infrastructure, and not for new behavior."
argument-hint: "[the bug to fix]"
---

# TDD bug fix

When fixing a bug with a clear, cheap test path, make the broken behavior executable before changing production code.
The goal is a focused regression test that fails before the fix and passes after it.

Do not force a test when it would be impractical.
If the available test would require broad harness setup, brittle mocks, slow end-to-end infrastructure, production-only state, vague reproduction steps, or large unrelated fixture churn, skip adding a new test and use the closest useful verification instead.

## Workflow

1. **Understand the bug.** Identify the intended behavior, current behavior, affected path, and smallest observable reproduction.
2. **Choose the narrowest executable check.** Prefer the closest unit, component, integration, or regression test already used for that code path. If no practical test path is obvious, do not create one from scratch just to satisfy the workflow.
3. **Write the failing test first.** Add the smallest focused test that would have caught the bug. The test should encode intended behavior, not mirror the current implementation, per the principle `test-behavior-not-implementation`.
4. **Run the new test before fixing.** Confirm it fails for the intended reason. If it passes or fails for an unrelated reason, correct the test or reproduction before editing the implementation.
5. **Commit the failing test.** It lands before the fix, so the history shows it failing first.
6. **Fix the bug.** Make the smallest production change that satisfies the intended behavior while preserving nearby contracts.
7. **Rerun the regression test.** Confirm the test now passes. It stays in the suite as a regression test.

## If a failing test is impractical

Use the closest executable regression check instead: a targeted script, a manual reproduction command, browser automation, a snapshot comparison, a log assertion, or a focused integration check.

Prefer no new test over a bad test.
A bad test is one that mostly tests mocks, encodes current implementation details, depends on timing or unrelated global state, or needs expensive infrastructure for a small fix.

## Guardrails

- Do not change tests merely to match a wrong implementation.
- Do not weaken existing assertions unless the expected behavior has genuinely changed and the reason is clear.
- Keep the regression test focused on the bug. Avoid broad fixture churn or unrelated coverage expansion.
- If the bug is flaky, make the test deterministic where possible and document the signal being locked down.
- If the bug exposes a broader class of failures, first land the focused regression path, then consider additional sibling coverage.

## Final response

Report the evidence, not just the outcome:

- Name the failing-before test or executable check and the failure it produced.
- Name the passing-after test run and any nearby validation performed.
- If failing-before evidence could not be demonstrated, state why and describe the closest regression check used instead.
