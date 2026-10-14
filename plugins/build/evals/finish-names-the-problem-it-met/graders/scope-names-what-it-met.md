---
type: regex
pattern: '\nMet on the way: (?:[\w.-]+/[\w.-]+)?#[1-9]\d*(?:(?:,| and|, and) (?:[\w.-]+/[\w.-]+)?#[1-9]\d*)*\.?\n(?:[ \t]*\n)*## Blast radius'
target: { source: file, path: .git/forge/pulls/feat/reject-negative-quantity.md }
---
