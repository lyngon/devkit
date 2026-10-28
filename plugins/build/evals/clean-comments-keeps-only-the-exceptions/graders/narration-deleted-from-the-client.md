---
type: regex
pattern: "Check the cache first|Save it in the cache"
match: not_contains
target: { source: file, path: rates/client.py }
---
