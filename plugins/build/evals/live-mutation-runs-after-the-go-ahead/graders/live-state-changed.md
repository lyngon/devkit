---
type: regex
pattern: '"retention_days": 90\b'
target: { source: file, path: .git/forge/cloud/production.json }
---
