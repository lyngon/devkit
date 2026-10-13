---
paths:
  - "devenv/**"
---

# Baseline values are defaults

Every value the baseline module sets is a `lib.mkDefault`, except a value that follows an option of the module itself, which a repository sets instead.

Why: a repository then overrides one value in place with a comment saying why, where a plain value would leave it `mkForce` or a fork of the baseline.
