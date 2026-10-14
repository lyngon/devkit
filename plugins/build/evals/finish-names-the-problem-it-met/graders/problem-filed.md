---
type: regex
pattern: '^(?:issue #\d+|pull #\d+ (?!feat/reject-negative-quantity )\S+) [^\n]*(?:refund|currency)'
flags: mi
target: { source: file, path: .git/forge/created.log }
---
