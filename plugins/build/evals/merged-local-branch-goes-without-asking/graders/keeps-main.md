---
type: regex
pattern: '^[0-9a-f]+ refs/heads/main$'
flags: m
target: { source: file, path: .git/packed-refs }
---
