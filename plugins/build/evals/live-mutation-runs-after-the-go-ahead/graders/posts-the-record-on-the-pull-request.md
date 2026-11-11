---
type: regex
pattern: '<!-- comment \d+ -->\n## Action record of `[^`]+`[\s\S]*\| Check \| Before the run \| After the run \| Demonstrations \|'
target: { source: file, path: .git/forge/pulls/feat/longer-log-retention.comments.md }
---
