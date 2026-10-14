---
type: regex
pattern: "^    permissions:\\n(?=(?:      .*\\n)*?      contents: read\\n)(?:      .*\\n)*?      packages: write\\n"
flags: m
target: { source: file, path: .github/workflows/ci.yml }
---
