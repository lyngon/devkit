---
type: regex
pattern: "pydantic|BaseModel"
match: not_contains
target: { source: file, path: libs/orders/src/orders/domain/order.py }
---
