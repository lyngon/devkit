# Session start never removes a worktree

Worktrees of crashed sessions, and worktrees the operator chose to keep, stay on disk until a person removes them, even when git sees nothing in them to keep.
Their ignored files, such as `tmp/` and `.terraform/`, may hold the only copy of a handover, a work trace or a proposal.
Claude Code already runs a worktree's life: it locks the worktree of a live session, offers to remove it at an interactive exit, and releases the lock of a session that died.

Enforced by: judgment
