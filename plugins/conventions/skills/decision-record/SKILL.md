---
name: decision-record
description: Lyngon conventions for decision records under docs/decisions/. Invoke before writing, editing or deleting a decision record.
user-invocable: false
paths:
  - "**/docs/decisions/*.md"
---

# Decision record conventions

The format and the rules are in [DECISION-RECORD-FORMAT.md](DECISION-RECORD-FORMAT.md): when to write a record, how to name it, what it holds, and when to delete it.
Read it before writing, editing or deleting one.

## With the Lyngon baseline

Checked by the `validate-documents`, `markdownlint` and `prose-lint` hooks.
