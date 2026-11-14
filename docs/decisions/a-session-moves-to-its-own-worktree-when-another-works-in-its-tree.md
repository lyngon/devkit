# A session moves to its own worktree when another works in its tree

Two live sessions in one working tree share `HEAD`, the index, the files and `tmp/`, so a branch switch or a commit in one changes what the other works on.
A session that starts or resumes in a working tree where another live session works, busy or idle, moves into a worktree of its own before it changes anything there.
A session alone in its tree stays where it started, so only the later session pays for a worktree, and the sharing never starts.
Until the later session has moved, or the other session has ended, the repo plugin refuses its edits and shell commands in that tree, because a message alone does not stop an unattended session that skims past it.
Nothing overrides the refusal: closing the other session lifts it.
When the later session's task continues the work on the branch checked out in the shared tree, it does not move: it asks the operator to close the other session, and it stays once that session has ended.

## Considered options

- A worktree for every session removes the sharing without detecting anything, but every session pays for it: a devenv entry of 5 to 24 s, `tofu init` per root module in lyngon.com, no access to the main checkout's `tmp/`, and the worktree guard that Claude Code puts on every isolated session. Two sessions can still meet in one worktree by its name or by a resume, so detection is needed anyway.
- Warning and carrying on, or asking the owner, leaves two sessions in one tree.
- Counting only busy sessions misses an idle one, which works again on the operator's next prompt.
- Telling the later session without refusing anything relies on an instruction for concurrency control.
- An override that the operator grants needs a marker with a lifetime, and the marker can outlive the reason it was granted for.

Enforced by: judgment
