# A session moves to its own worktree when another works in its tree

Two live sessions in one working tree share `HEAD`, the index, the files and `tmp/`, so a branch switch or a commit in one changes what the other works on.
A session that starts or resumes in a working tree where another live session works, busy or idle, moves into a worktree of its own before it changes anything there.
A session alone in its tree stays where it started, so only the second session pays for a worktree, and the sharing never starts.

## Considered options

- A worktree for every session removes the sharing without detecting anything, but every session pays for it: a devenv entry of 5 to 24 s, `tofu init` per root module in lyngon.com, no access to the main checkout's `tmp/`, and the worktree guard that Claude Code puts on every isolated session. Two sessions can still meet in one worktree by its name or by a resume, so detection is needed anyway.
- Warning and carrying on, or asking the owner, leaves two sessions in one tree.
- Counting only busy sessions misses an idle one, which works again on the owner's next prompt.

Enforced by: judgment
