---
type: regex
pattern: '(?:^|\n)## Verified\n(?:(?!\n## )[\s\S])*comment'
flags: i
target: { source: file, path: .git/forge/pulls/feat/reject-negative-quantity.md }
---
