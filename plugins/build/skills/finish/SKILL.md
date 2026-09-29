---
name: finish
description: >-
  Finish a development branch: run the repository's full check, remove the plan file
  in a final commit, present the integration menu (merge locally, push and open a
  pull request, or keep the branch), execute the choice and clean up the worktree.
  Use when a plan's tasks are complete and the whole-branch review is clean, or when
  any feature branch is done and needs integrating: "the plan is done, wrap up the
  branch", "finish this branch", "integrate this". Not for committing a single change.
---

# Finish

## Overview

Core principle: verify the full check, remove the plan, detect the environment, present options, execute the choice, clean up.

## Step 1: Run the full check

Run the repository's full check: every lint and every test, as the repository's own instructions name it (`npm test`, `cargo test`, `pytest` and `go test ./...` are examples of a test command, not the assumption).

If it fails, report the failures and stop; the menu comes after a green check:

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
Without a `progress.md`, no executor produced the branch and there is no ledger.

Then remove the plan in a final commit:

```bash
git rm docs/plans/YYYY-MM-DD-<slug>.md
git commit -m "chore: remove the plan for <slug>"
```

The plan was transient: the work is in the git history, and what mattered beyond the work was recorded as a decision, not left in the plan.

### With the Lyngon documents

Before deleting, read the plan's `## Design` section for a decision that meets the ADR bar (hard to reverse, surprising without context, the result of a real trade-off) and is not yet in `docs/adr/`.
Record it first: call the Skill tool for `discover:domain-model`, commit the ADR, then remove the plan.

Before deleting, also offer the findings nobody acted on to `docs/TODO.md`, since the ledger goes with the workspace.
Collect the executor's "Deferred minors" and the ledger's `minor (deferred)` and parked lines, each finding once:

```bash
grep -E 'minor \(deferred\)|: parked;' "$PLAN_WORKSPACE/progress.md"
```

```text
Deferred findings from the execution:

1. <finding>
2. <finding>

Which of these go to docs/TODO.md? (numbers, "all" or "none")
```

Add the chosen ones to `docs/TODO.md`, one line each with today's date (`- YYYY-MM-DD: <item>`), and stage the file so it lands in the plan-removal commit.
A branch no executor produced has no ledger: say so and move on.

## Step 3: Detect the environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace: Step 6 changes directory
# before cleanup (Step 7) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
| --- | --- | --- |
| `GIT_DIR == GIT_COMMON` (normal repository) | Standard 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (see Step 7) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | Externally managed, leave in place |

## Step 4: Determine the base branch

The base branch is whatever this work forked from, usually named in the plan, the conversation, or the branch's upstream.
If it is not already known, ask: "This branch split from [your best guess], is that correct?"
Confirm before merging: merging into the wrong base is expensive to undo.

## Step 5: Present the options

For a normal repository and a named-branch worktree, present exactly these 3 options:

```text
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a pull request
3. Keep the branch as it is (I'll handle it later)

Which option?
```

For a detached HEAD, present exactly these 2 options:

```text
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as a new branch and create a pull request
2. Keep as it is (I'll handle it later)

Which option?
```

Present the menu exactly as written: concise, with every option coming from the list above.
Discarding the work happens only in response to the user explicitly asking for it (see "If the user asks to discard the work" below).
Wait for their answer; the integration decision is theirs.

## Step 6: Execute the choice

### Option 1: Merge locally

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

### Option 2: Push and create a pull request

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

Then create the pull request (or merge request) against the base branch with the forge's tooling: its CLI if one is available, or the creation URL most forges print when you push.
Follow the repository's pull request template and conventions if present.

The description opens with the "Rulings I made" and "Deferred minors" lists from the executor's final message, so the user's review of the branch starts where the decisions taken on their behalf are.
When the branch was not produced by an executor, open with a short summary of the branch instead.
Report the URL to the user.

Keep the worktree and the plan workspace: the work has not landed, and the user iterates on pull request feedback in the worktree.

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

### Option 3: Keep as it is

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

Runs for Option 1 and confirmed discards.
Options 2 and 3 always preserve the worktree and the plan workspace, since the work has not landed.
Both callers have already changed directory to the main repository root (worktree removal must run from outside the worktree) and use the `PLAN_WORKSPACE` value resolved in Step 2 and the `GIT_DIR`, `GIT_COMMON` and `WORKTREE_PATH` values captured in Step 3, from before that directory change.

**If Step 2 resolved a plan workspace:** remove it; the work has landed or been discarded, and Step 2 offered its deferred findings to the user:

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

| Option | Merge | Push | Keep worktree and plan workspace | Clean up branch |
| --- | --- | --- | --- | --- |
| 1. Merge locally | yes | - | - | yes |
| 2. Create a pull request | - | yes | yes | - |
| 2, after the forge merged it (landing steps) | fast-forward the base (`git pull --ff-only`) | - | - | yes |
| 3. Keep as it is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (force) |

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "The check passed earlier this session" | Run the full check on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "The plan file is harmless, leave it" | The plan was transient. Its decisions belong in the ADRs and its work in the history; the branch is not finished while it carries one. |
| "They obviously want it merged" | Integration is the user's decision. Present the menu and wait. |
| "They seem done with this feature, I'll offer to discard it" | The menu is complete as written. Discard happens only when the user asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The deferred minors are in the executor's message, that's enough" | The message scrolls away and the ledger goes with the workspace. Offer them for the TODO list before the plan is removed. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "The PR is up, the local base branch will catch up on its own" | It will not. The next session starts on a stale base and misses what landed. End the report with the landing steps. |
| "This other worktree looks stale, I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Removal refused, `--force` is just finishing the cleanup" | The refusal means files exist only in that worktree. `--force` destroys them permanently. Show the user and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "The base branch is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected, force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on the user's explicit request. |
