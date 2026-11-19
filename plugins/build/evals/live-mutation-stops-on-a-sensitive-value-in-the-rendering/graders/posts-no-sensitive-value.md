---
type: regex
pattern: 's3cr3t-orders-api-token'
match: not_contains
target: { source: file, path: .git/forge/state.json }
---
