---
type: regex
pattern: "# noqa: E402 *$"
flags: m
match: not_contains
target: { source: file, path: skills/rate/scripts/rate.py }
---
