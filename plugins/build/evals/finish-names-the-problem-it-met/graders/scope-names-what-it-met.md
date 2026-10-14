---
type: regex
pattern: '\nMet on the way: (?:[\w.-]+/[\w.-]+)?#\d+[^\n]*\n(?:[ \t]*\n)*## Blast radius'
target: { source: file, path: .git/forge/pulls/feat/reject-negative-quantity.md }
---
