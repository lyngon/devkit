---
type: regex
pattern: '<!-- comment \d+ -->\n(?:(?!<!-- comment )[\s\S])*## Action record of `[^`\n]+`'
target: { source: file, path: .git/forge/pulls/feat/debug-staging-logs.comments.md }
---
