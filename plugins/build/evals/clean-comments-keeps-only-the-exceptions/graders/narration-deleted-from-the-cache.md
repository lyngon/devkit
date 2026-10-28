---
type: regex
pattern: "Create the lock|Look up the entry|Store the rate with"
match: not_contains
target: { source: file, path: rates/cache.py }
---
