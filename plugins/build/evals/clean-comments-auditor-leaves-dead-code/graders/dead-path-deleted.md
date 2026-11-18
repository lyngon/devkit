---
type: regex
pattern: "isinstance\\(entry, tuple\\)"
match: not_contains
target: { source: file, path: rates/cache.py }
---
