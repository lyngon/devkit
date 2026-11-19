---
type: regex
pattern: '\tcommit: feat\(rates\): refuse a currency that the provider does not quote\n[\s\S]*\tcommit: '
target: { source: file, path: .git/logs/HEAD }
---
