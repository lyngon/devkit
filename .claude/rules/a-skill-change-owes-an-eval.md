---
paths:
  - "plugins/**/skills/**"
  - "plugins/**/hooks/**"
  - "plugins/**/agents/**"
---

# A skill change owes an eval

A change that alters what an agent does (a new skill, a changed procedure or trigger) adds or updates an eval case for the behaviour it claims, and reports the suite's score at the base commit and at head.
A change of wording alone owes the validators.

Why: nothing fails when a skill's text stops producing the behaviour it describes.
