---
name: request
description: >-
  Dispatch a fresh reviewer subagent with a crafted brief, a commit range and the plan or
  requirements, then act on its findings by severity. Use when a task or feature is complete
  and there is code to review: before merging ("get this reviewed before I merge"), after each
  task in build:delegate, at the end of build:execute, or when stuck and wanting a fresh look
  at the code.
---

# Request a code review

Dispatch a reviewer subagent to catch issues before they cascade.
The reviewer gets precisely crafted context for its evaluation, never your session's history.

**Core principle:** review early, review often.

## When to request a review

Mandatory:

- After each task in `build:delegate`
- At the end of `build:execute`
- After completing a major feature
- Before merging to the main branch

Optional but valuable:

- When stuck (a fresh perspective)
- Before refactoring (a baseline check)
- After fixing a complex bug

## How to request

### 1. Get the git range

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or, for a whole branch: git merge-base main HEAD
HEAD_SHA=$(git rev-parse HEAD)
```

`HEAD~1` covers the last commit only.
A task or branch that spans several commits needs the commit you recorded before starting it, or the merge base.

### 2. Dispatch the reviewer subagent

Fill the template in [references/code-reviewer.md](references/code-reviewer.md) and dispatch a subagent with it.
Specify the model explicitly; a whole-branch review is a judgment task and deserves the most capable tier.

Placeholders:

- `{DESCRIPTION}`: a brief summary of what you built.
- `{PLAN_OR_REQUIREMENTS}`: what it should do; a plan file path, its Design section, or requirements text.
- `{BASE_SHA}`: the starting commit.
- `{HEAD_SHA}`: the ending commit.
- `{REVIEW_PACKAGE}` (optional): the path of a review package file when one exists, such as the file that `build:delegate`'s `review-package` script prints. The reviewer then reads one file instead of re-deriving the diff.
- `{REVIEW_FOCUS}` (optional): the plan's Review Focus section, verbatim.
- `{RULINGS}` (optional): the `Ruling:` lines from the execution ledger.

Leave out a template section whose placeholder has nothing to fill it.

### 3. Act on the findings

- Fix Critical issues immediately.
- Fix Important issues before proceeding.
- Note Minor issues for later.
- Rule on every line under "Declined to judge": fix it, or record why the code stands.
- Push back if the reviewer is wrong, with reasoning.
  Invoke `review:receive` to evaluate the findings before acting on them.

## Example

```text
[Just completed Task 2: add the verification function]

You: Requesting a code review before proceeding.

BASE_SHA=$(git rev-parse a7981ec)   # the commit recorded before Task 2 started
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch the reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 in docs/plans/2026-09-23-deployment.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]
  Strengths: clean architecture, real tests
  Issues:
    Important: missing progress indicators
    Minor: magic number (100) for the reporting interval
  Declined to judge: none
  Assessment: ready to proceed

You: [Fix the progress indicators]
[Continue to Task 3]
```

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "I'll just review the diff myself instead of dispatching a reviewer" | You are the coordinator. Reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not on your thought process. |
| "It's a small change, review is overkill" | Small changes cascade too. The review costs one subagent; the bug it catches costs every task built on top of it. |

## Red flags

Never:

- Skip the review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

If the reviewer is wrong:

- Push back with technical reasoning
- Show the code or tests that prove it works
- Request clarification

`review:receive` covers how to evaluate and answer the findings.
