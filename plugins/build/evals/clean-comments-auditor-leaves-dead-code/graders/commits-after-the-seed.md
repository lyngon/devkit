---
type: regex
pattern: '\tcommit: feat\(rates\): cache each rate for ten minutes\n[\s\S]*\tcommit: '
target: { source: file, path: .git/logs/HEAD }
---
