---
name: pull-request
description: "Hand a finished change over as one pull request: the comments of the change cleaned, the full check green on the pushed head, a Conventional Commits title and a body under seven fixed headings that check-pull-request accepts, the pull request open and ready, and the branch's work trace posted on it. Use on your own whenever a change is done and its full check passes, in every session, and for 'open the pull request', 'hand it over' or 'ship this branch'. Not for a commit on the branch."
argument-hint: "[the change to hand over]"
---

# Pull request

A change is one concern, delivered as one pull request that lands as one squash commit.
The title becomes the subject of that commit and the body its message, so both describe the whole change as the commit will.

## What must hold

- `build:clean-comments` ran over the diff of the change, and what it changed is committed.
- The full check, `devenv test`, passed on the head you pushed. Commits made after a green run, those of `build:clean-comments` included, need a new run before the push.
- The title is `<type>(<scope>): <subject>` in Conventional Commits form, short and imperative, with no trailing period. The scope is the area the change touches. Name a real symbol when one carries the change. A breaking change has `!` before the colon.
- The body has exactly the seven headings below, in this order, and no other second-level heading.
- `check-pull-request` accepts the title and the body. It prints nothing when both pass, warns above the target length and fails above the limit, and its message names the numbers and the ways out.
- The pull request is open and ready, not a draft, and you report its link.
- When `tmp/work-trace/` holds the branch's work trace, the trail and its Attention section are one comment on the pull request, and Verified points at it.
- A mistake ledger file under `docs/mistakes/` that the change wrote before the pull request existed links the pull request in its line **Caught in**, and that commit is pushed too.
- After every later push the title and the body are true again.

Run `check-pull-request` with the title in `PR_TITLE` and the body in `PR_BODY`, before you open the pull request and after every change to either.
Keep the body in a file under `tmp/` at the root of the repository, which git ignores:

```sh
PR_TITLE="feat(orders): reject a negative quantity" PR_BODY="$(cat tmp/pull-request-body.md)" check-pull-request
```

CI runs the same check on the pull request.
Never change the length options of the baseline to make a body pass; cut the body by one of the ways out that the message names.

## The body

A reviewer who has the diff learns from the body why the change exists, what it leaves out, what it could break and how it was proven, in under a minute.
It is a briefing, not a lab notebook.
Write short, simple sentences with few identifiers, no SHAs and no history of rebases.
Write it, and the title, with `writing:technical`, every layer but Diátaxis, then apply `writing:unslop`.

```text
## Why
## Decisions
## What changed
## Scope
## Blast radius
## Verified
## Not verified
```

- **Why**: the problem and the approach, in one to three sentences.
- **Decisions**: for each decision, what was decided, the alternatives and how they were compared, the trade-off accepted and the steering document changed. An entry that replaces a decision record says `replaces <name>`. With none, write "None".
- **What changed**: one to three bullets. Name both sides of a rename.
- **Scope**: what the change covers and what it deliberately leaves out. It ends with the line `Met on the way:`, followed by `nothing` or by each issue and pull request for a problem the work met, as in `Met on the way: #12 and #15.`
- **Blast radius**: who or what the change touches, and why that is safe or risky.
- **Verified**: one to three bullets, each a command or a run path and what it showed.
- **Not verified**: what the change claims or touches that no run covered, and why. With none, write "None".

A problem that the work met counts whether or not the change caused it, a check that shows it included, such as a skipped test whose reason names a bug.
File an issue for it with the evidence, or fix it in a pull request of its own when a run can prove the fix, and name it in the line.

Evidence too long for the body goes into a comment on the pull request, which Verified points at.
The body carries no line that names the tool or the agent that wrote it, since it becomes the commit message.

## The work trace

The branch's work trace is `tmp/work-trace/<branch>.tsv`, where `<branch>` is the name of the branch with each `/` replaced by `-`, and its Attention section is `tmp/work-trace/<branch>.md` beside it, both written by `build:work-trace`.
When the log exists, post one comment on the pull request once it is open: the trail as the table that the helper of `build:work-trace` prints, then the Attention section.
Verified points at that comment.
After a later push that adds rows, post the trail again in a new comment and point Verified at it.

## Pushing and opening

Push the branch and open the pull request against the branch it started from, without asking.
The owner reviews the pull request and decides the merge.

- Without a remote, there is nothing to push: report the title and the body, with the branch and its commits.
- With a remote and no forge tool, or one that is not signed in, push and hand over the link the forge printed.
- When a pull request for the branch exists, the push updated it: edit its title and body instead of opening another.
- A rejected push means the remote moved. Integrate the remote commits, run the full check again and push again. Never force-push without asking.
- A change that needs one that has not merged branches from it, and its pull request targets that branch. When the parent gets fixes from its review, merge the parent into the child; nothing is force-pushed.
- Opening the pull request does not start a watch over it. Report the link and go on with the work.
