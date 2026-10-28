---
type: regex
pattern: "#[^\\n]*HTTP 200[\\s\\S]*#[^\\n]*rates\\.example\\.com/docs/errors#rate-limits"
target: { source: file, path: rates/client.py }
---
