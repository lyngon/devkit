---
type: regex
pattern: '^issue #\d+ '
flags: m
target: { source: file, path: .git/forge/created.log }
---
