---
type: regex
pattern: '^pull #\d+ feat/brevity '
flags: m
target: { source: file, path: .git/forge/created.log }
---
