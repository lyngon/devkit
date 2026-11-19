---
type: regex
pattern: "#[^\\n]*(sorted|bisect|every currency|whenever the page)"
match: not_contains
target: { source: file, path: rates/client.py }
---
