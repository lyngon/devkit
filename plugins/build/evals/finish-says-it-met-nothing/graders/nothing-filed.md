---
type: regex
pattern: '^(?:issue #|pull #\d+ (?!feat/reject-negative-quantity ))'
flags: m
match: not_contains
target: { source: file, path: .git/forge/created.log }
---
