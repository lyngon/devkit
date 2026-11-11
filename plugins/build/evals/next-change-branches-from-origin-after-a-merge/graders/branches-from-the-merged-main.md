---
type: regex
pattern: '^\S+ c83c9e109bb7a0955af7ee95f0149cc4da2378d6 [^\t]*\tcheckout: moving from \S+ to (?!main$)\S+$'
flags: m
target: { source: file, path: .git/logs/HEAD }
---
