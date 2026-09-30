---
name: finish
description: >-
  Finish a development branch: run the repository's full check, remove the plan file
  in a final commit, push the branch and open a pull request (without asking where the
  user's standing instructions cover it; merging locally or keeping the branch only on
  request), and keep the worktree until the work lands. Use when a plan's tasks are
  complete and the whole-branch review is clean, or when any feature branch is done:
  "the plan is done, wrap up the branch", "finish this branch", "open the pull
  request". Not for committing a single change.
---

# Finish

## Overview

Core principle: verify the full check, remove the plan, detect the environment, push and open the pull request, and clean up only what has landed.

## Step 1: Run the full check

Run the repository's full check: every lint and every test, as the repository's own instructions name it (`npm test`, `cargo test`, `pytest` and `go test ./...` are examples of a test command, not the assumption).

If it fails, report the failures and stop; the push comes after a green check:

```text
Full check failing (<N> failures). Must fix before completing:

[Show failures]
```

If it passes, continue to Step 2.

### With devenv

The full check is `devenv test`: it runs every git hook on every file plus the repository's tests.

## Step 2: Remove the plan

When the branch carries a plan file, `docs/plans/YYYY-MM-DD-<slug>.md`, first resolve the plan's workspace while the file still exists.
The script lives in `build:delegate`, at `../delegate/scripts/workspace` from this skill's directory:

```bash
PLAN_WORKSPACE=$(bash <this skill's directory>/../delegate/scripts/workspace docs/plans/YYYY-MM-DD-<slug>.md)
```

`build:delegate` and `build:execute` hand this directory over instead of deleting it: its `progress.md` is their ledger, and Step 7 removes the directory once the work lands.
When it has no `progress.md` but the plan ends with an `## Execution status` section, a paused run left its ledger in the plan: recreate it before the plan goes, with `bash <this skill's directory>/../delegate/scripts/execution-status restore docs/plans/YYYY-MM-DD-<slug>.md`.
Without either, no executor produced the branch and there is no ledger.
Collect the ledger's owner gates for the description (Step 5):

```bash
grep -E '^Gate ' "$PLAN_WORKSPACE/progress.md"
```

Then remove the plan in a final commit:

```bash
git rm docs/plans/YYYY-MM-DD-<slug>.md
git commit -m "chore: remove the plan for <slug>"
```

The plan was transient: the work is in the git history, and what mattered beyond the work was recorded as a decision, not left in the plan.

### With the Lyngon documents

Before deleting, read the plan's `## Design` section for a decision that meets the ADR bar (hard to reverse, surprising without context, the result of a real trade-off) and is not yet in `docs/adr/`.
Record it first: call the Skill tool for `discover:domain-model`, commit the ADR, then remove the plan.

Before deleting, also collect the findings nobody acted on: the executor's "Deferred minors" and the ledger's `minor (deferred)` and parked lines, each finding once:

```bash
grep -E 'minor \(deferred\)|: parked;' "$PLAN_WORKSPACE/progress.md"
```

They go into the pull request description (Step 5), and the report then asks which of them go to `docs/TODO.md`; nothing waits on that answer.
A branch no executor produced has no ledger: say so and move on.

## Step 3: Detect the environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace: a local merge changes
# directory before cleanup (Step 7) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
git remote -v
```

This determines how the branch is pushed and how cleanup works:

| State | Push | Cleanup |
| --- | --- | --- |
| `GIT_DIR == GIT_COMMON` (normal repository) | The branch, with its upstream | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | The branch, with its upstream | Provenance-based (see Step 7) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | HEAD as a new branch; no local merge | Externally managed, leave in place |

Without a remote there is nothing to push; Step 5 says what to do instead.

## Step 4: Determine the base branch

The base branch is whatever this work forked from, usually named in the plan, the conversation, or the branch's upstream, and otherwise the remote's default branch.
For the pull request, take it without asking: a wrong base is changed on the forge in one step.
A local merge (Step 6, on request) is different: first ask "This branch split from [your best guess], is that correct?", because merging into the wrong base is expensive to undo.

## Step 5: Push and open the pull request

Push the feature branch and open its pull request.
Ask once, right before the push, unless the user's standing instructions cover pushing and opening a pull request; then do both without asking.
The answer covers the branch's later pushes too: the `docs(todo)` commit below and fixes asked for on the pull request.

```text
Full check green. Push <feature-branch> and open a pull request against <base-branch>?
(Or merge locally, or keep the branch as it is: Step 6.)
```

When Step 2 added commits after Step 1's full check (an ADR, the plan removal), run the full check again first: the push carries them.
The user reviews the pull request and decides the merge.
Merge locally or keep the branch instead only when the user asked for that (Step 6).

Without a remote, there is nothing to push: report the branch and its commits, keep the worktree and the plan workspace, and stop.

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

A rejected push means the remote moved.
Investigate, integrate the remote commits (rebasing only commits that were never pushed), run the full check again and push again.
Force-push only when the user asks for it.

Then open the pull request (or merge request) against the base branch with the forge's CLI.
When a pull request for this branch already exists, the push has updated it: update its description instead of opening another.
Without a forge CLI, or with one that is not signed in, hand over the creation link the forge printed on push.
Follow the repository's pull request template and conventions if present.

The description carries, in this order:

1. What changed and why, in a short paragraph.
2. "Decisions for you": anything the user must decide, or "none".
3. When an executor produced the branch, its "Rulings I made" and "Deferred minors" lists, and a link to the plan file at the parent of the plan-removal commit, since the plan does not show in the pull request's diff.
4. When the ledger has owner gates, an "Owner gates" list: each gate's ID, the owner's answer verbatim with its time or the pre-approval, and the record commit that ends its task.
5. Review findings nobody fixed.
6. Verification: the full check command and its result, and any other evidence by name.

Report the URL to the user.

When Step 2 collected deferred findings, the report ends by asking which go to `docs/TODO.md`:

```text
Deferred findings from the execution (also in the pull request description):

1. <finding>
2. <finding>

Which of these go to docs/TODO.md? (numbers, "all" or "none")
```

Add the chosen ones to `docs/TODO.md`, one line each with today's date (`- YYYY-MM-DD: <item>`), commit them as `docs(todo): defer findings from <slug>`, run the full check and push; the pull request picks the commit up.

Keep the worktree and the plan workspace: the work has not landed.
Changes asked for on the pull request are made in the worktree as new commits and pushed after the full check; update the description when its lists change.

The merge then happens on the forge, and the local base branch does not follow it.
End your report with the landing steps for after the merge, with the paths and names filled in and the lines that do not apply left out, so the user or the next session can run them:

```bash
cd <main repository root>
git switch <base-branch>
git pull --ff-only
rm -rf <plan workspace>                # when Step 2 resolved one
git worktree remove <worktree path>    # only under .worktrees/ or worktrees/, as in Step 7
git branch -d <feature-branch>         # after the worktree: git refuses to delete a checked-out branch
```

A forge that squashed or rebased the pull request leaves the local branch unmerged in git's eyes, so `git branch -d` refuses it.
Check that the pull request shows as merged, then delete it with `-D`.

### With the Lyngon workflow

The user's standing instructions in `conventions:engineering` cover pushing the feature branch and opening its pull request: do both without asking.

## Step 6: Other outcomes, on request

Only when the user asked for one of these instead of the pull request.
Each one ends its report with the question about `docs/TODO.md` from Step 5 when Step 2 collected deferred findings, and answers it before Step 7 removes the plan workspace.

### Merge locally

```bash
# Get the main repository root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first; verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify the full check on the merged result
<full check>
```

If the check fails on the merged result: stop, leave the worktree and branch in place, and investigate; nothing has been pushed, so the merge is local and recoverable.

Once the merged result is green: clean up the plan workspace and the worktree (Step 7), then delete the branch:

```bash
git branch -d <feature-branch>
```

### Keep as it is

Report: "Keeping branch [name]. Worktree preserved at [path]."

### If the user asks to discard the work

This path exists only as a response to an explicit request to throw the work away.
Confirm first:

```text
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation.
When it arrives:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the plan workspace and the worktree (Step 7), and force-delete the branch:

```bash
git branch -D <feature-branch>
```

## Step 7: Clean up the plan workspace and the worktree

Runs for a local merge and a confirmed discard.
The pull request and a kept branch always preserve the worktree and the plan workspace, since the work has not landed.
Both callers have already changed directory to the main repository root (worktree removal must run from outside the worktree) and use the `PLAN_WORKSPACE` value resolved in Step 2 and the `GIT_DIR`, `GIT_COMMON` and `WORKTREE_PATH` values captured in Step 3, from before that directory change.

**If Step 2 resolved a plan workspace:** remove it; the work has landed or been discarded, and its deferred findings were offered for `docs/TODO.md`:

```bash
rm -rf "$PLAN_WORKSPACE"
```

Sibling directories under `tmp/build/` belong to other plans; leave them alone.

**If `GIT_DIR == GIT_COMMON`:** a normal repository, no worktree to clean up.
Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** the executor created this worktree; we own cleanup:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**If removal is refused** (`contains modified or untracked files`): the worktree holds files that exist nowhere else, such as uncommitted notes or scratch work.
Never `--force` on your own initiative.
Show the user what is at stake and ask:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```text
Worktree removal refused; these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repository root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then remove the worktree.

**Otherwise:** the host environment owns this workspace; leave it in place.
If your platform provides a workspace-exit tool, use it.

## Quick reference

| Outcome | Merge | Push | Keep worktree and plan workspace | Clean up branch |
| --- | --- | --- | --- | --- |
| Pull request (the default) | - | yes | yes | - |
| Pull request, after the forge merged it (landing steps) | fast-forward the base (`git pull --ff-only`) | - | - | yes |
| Merge locally (on request) | yes | - | - | yes |
| Keep as it is (on request) | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (force) |

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "The check passed earlier this session" | Run the full check on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "The plan file is harmless, leave it" | The plan was transient. Its decisions belong in the ADRs and its work in the history; the branch is not finished while it carries one. |
| "They obviously want it merged" | Merging is the user's decision. Open the pull request; merge locally only when they ask. |
| "Let me ask before pushing" | Where the user's standing instructions cover the push, asking puts it back in series with the work. Without them, ask once, right before the push. |
| "The pull request is up, I'll amend the commit to fix a typo" | Pushed history is not rewritten without asking. Fix it in a new commit and push after the full check. |
| "They seem done with this feature, I'll offer to discard it" | Discard happens only when the user asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The deferred minors are in the executor's message, that's enough" | The message scrolls away and the ledger goes with the workspace. Put them in the pull request description and ask which go to the TODO list. |
| "I'll ask about the TODO list before opening the pull request" | The user may be away; the TODO question must never hold up the push. Open the pull request first, then ask. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "The PR is up, the local base branch will catch up on its own" | It will not. The next session starts on a stale base and misses what landed. End the report with the landing steps. |
| "This other worktree looks stale, I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Removal refused, `--force` is just finishing the cleanup" | The refusal means files exist only in that worktree. `--force` destroys them permanently. Show the user and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "The base branch is obviously main" | Before a local merge, confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected, force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on the user's explicit request. |
| "The workspace is gone, so the ledger is lost" | A paused run left a copy in the plan's Execution status. Restore it before the plan is removed. |
