# Session start never removes a worktree or a branch it holds

Worktrees of crashed sessions, and worktrees the operator chose to keep, stay on disk until a person removes them, even when git sees nothing in them to keep.
Their ignored files, such as `tmp/` and `.terraform/`, may hold the only copy of a handover, a work trace or a proposal.
Claude Code already runs a worktree's life: it locks the worktree of a live session, offers to remove it at an interactive exit, and releases the lock of a session that died.

Session start may delete local branches whose changes are already in the default branch, but never one that a worktree holds.
A worktree holds the branch checked out in it, and the branch `worktree-<name>` that Claude Code created with `.claude/worktrees/<name>`, even while another branch is checked out there.
Claude Code's exit prompt and its reuse of a worktree name both work from that branch, and its removal of the worktree deletes it.

Enforced by: judgment
