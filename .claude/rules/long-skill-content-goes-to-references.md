---
paths:
  - "plugins/**/SKILL.md"
---

# Long skill content goes to references

What every invocation of a skill needs stays in its `SKILL.md`; the rest goes into `references/` files next to it, linked by relative path.

Why: the whole `SKILL.md` enters the context on every invocation, and a reference is read only by the invocation that needs it.
