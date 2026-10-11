---
paths:
  - "plugins/**"
  - "catalog/**"
---

# Third-party skills enter through add-skill

Third-party text enters the devkit only through `/devkit:add-skill`, which reviews it against `shared/SKILL-REVIEW.md` and writes its provenance record.
Every later change to a vendored skill is listed under "Local patches" in its `UPSTREAM.md`.

Why: vetted means that a named person read the text at a recorded commit, and the list of patches is where a comparison with a newer upstream starts.
