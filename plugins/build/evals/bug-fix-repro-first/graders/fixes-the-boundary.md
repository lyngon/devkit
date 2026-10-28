---
type: regex
pattern: 'quantity >= BULK_QUANTITY|BULK_QUANTITY <= quantity'
target: { source: file, path: src/orders/pricing.py }
---
