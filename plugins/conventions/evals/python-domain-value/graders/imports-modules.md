---
type: regex
pattern: "from (dataclasses|typing|collections\\.abc|datetime) import"
match: not_contains
target: { source: file, path: libs/orders/src/orders/domain/order.py }
---
