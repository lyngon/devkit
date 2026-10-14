---
type: regex
pattern: "^permissions:\\n  contents: read\\n(?! )"
flags: m
target: { source: file, path: .github/workflows/ci.yml }
---
