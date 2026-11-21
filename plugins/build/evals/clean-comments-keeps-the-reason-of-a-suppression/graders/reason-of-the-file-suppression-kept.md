---
type: regex
pattern: "^# ruff: noqa: INP001 +# a script that the skill runs by its path, which no package holds$"
flags: m
target: { source: file, path: skills/rate/scripts/rate.py }
---
