---
name: clean-comments
description: "Delete the comments of a change that its code should say instead: spawn the build:comment-auditor agent over the change, vet what it deleted and flagged, fix the accepted flags at their root, and encode each constraint that a comment claims. Use before a change goes to a pull request, and for 'no comments' or 'clean the comments'."
argument-hint: "[files or a diff, or nothing for the branch's diff]"
---

# Clean comments

Spawn the agent `build:comment-auditor`.
Act on accepted findings.

Defer to the auditor's fresh perspective.

The principles this skill names are files of `principles:index`.
Read each one before you apply it.

## Scope

Use the caller's files or diff.
Otherwise use the current diff against the base branch, the default branch unless the branch targets another, including the working tree.

## Steps

1. **Spawn the auditor.** Spawn the agent `build:comment-auditor` (the Agent tool's `subagent_type`) in the foreground (`run_in_background: false`). Pass the scope. Do not restate its rules.
2. **Vet its report.** Inspect its report and diff. Reject application-code edits, scope escapes, deletions that its exceptions protect, misstated `MUST KILL` reasons, and flags that treat kept intentional code as guilty. Reshape flags on our-code surprises stay actionable. Do not restore those comments. A keep survives only with proof that it is about something we cannot change, or that it states a reason or an invariant that the code cannot show and no check holds. Audit missed scoped lint and type-checker suppressions. Correctness or safety suppressions stay actionable `MUST KILL`s. Restore deletions only with exact exceptions and scoped proof. Before accepting thin `IMPORTANT` or `do not remove` kills or keeps, have a subagent of its own invoke `discover:how` or `discover:why` on their symbol, started in the foreground (`run_in_background: false`). If a kill is ambiguous, do not restore. If a keep is refuted or still ambiguous, delete it. Revert and rerun one rejected report with the failure named. Reject a second, report it open, and end this skill as failed.
3. **Fix the trivial flags.** Fix trivial accepted flags directly by deleting a dead path, dropping a parameter, or using the real API. If any fix needs a shape, invoke `build:architect` once for the accepted set and surrounding code. Stop at its sketch, then continue here: it shapes, and "Fix at the root" implements.
4. **Fix at the root.** Implement the smallest root-cause fix in scope. Remove every named workaround. If the root cause is out of scope, land the smallest in-scope fix and report the rest open. The principles `fix-root-causes` and `redesign-from-first-principles` guide intent only. Neither authorizes widening the fence nor fixing instances outside it. Never bolt on symptom guards.
5. **Encode the constraints.** Constraint comments say `do not remove`, `do not change wording`, or `talk to X before changing`. Leave keeps about things we cannot change. For every other one, encode the constraint as the cheapest in-scope type, runtime check, test, or CI lint, then delete the comment, and name the encoding in your reply, so that the owner can reject it on the pull request. When no encoding fits in scope, delete the comment, report the constraint open, and sketch the out-of-scope work.
6. **Report.** Report the deletion count, restored comments, reruns, the sketch of `build:architect`, fixes, encodings, unenforced constraints, and other open work.
