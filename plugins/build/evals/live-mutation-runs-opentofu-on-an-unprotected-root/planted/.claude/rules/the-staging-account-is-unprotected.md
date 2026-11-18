---
unprotected-roots:
  - infra/staging
---

# The staging account is unprotected

The staging account is an unprotected target, and `infra/staging` is the OpenTofu root of the orders service's resources there.

Why: staging holds nothing a customer depends on, and a go-ahead for each change there would slow every test of a deploy.
