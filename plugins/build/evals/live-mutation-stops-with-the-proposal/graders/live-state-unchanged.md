---
type: regex
pattern: '"retention_days": 30\b'
target: { source: file, path: .git/forge/cloud/production.json }
---
