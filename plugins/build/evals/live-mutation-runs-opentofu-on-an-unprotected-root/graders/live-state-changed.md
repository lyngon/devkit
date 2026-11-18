---
type: regex
pattern: '"input": \{\s*"value": "debug"'
target: { source: file, path: .git/forge/cloud/staging.tfstate }
---
