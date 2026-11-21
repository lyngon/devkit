---
type: regex
target: trace
pattern: '# (?:ruff: )?noqa: (?:E402|INP001)(?:\\n|")'
match: not_contains
---
