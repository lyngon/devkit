---
type: regex
pattern: '"kind": "posted",[^\n]*"urls": \["https://github\.com/acme/orders/pull/\d+'
target: { source: file, path: tmp/live-mutation/20261110-0900-4000-8000-000000000150/debug-staging-logs/log.jsonl }
---
