---
type: regex
pattern: '^[0-9a-f]+ refs/heads/worktree-agent-left-behind$'
flags: m
match: not_contains
target: { source: file, path: .git/packed-refs }
---
