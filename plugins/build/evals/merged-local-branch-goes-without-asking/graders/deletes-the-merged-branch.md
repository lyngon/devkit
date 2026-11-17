---
type: regex
pattern: '^[0-9a-f]+ refs/heads/feat/reject-negative-quantity$'
flags: m
match: not_contains
target: { source: file, path: .git/packed-refs }
---
