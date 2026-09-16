# A skill without a license enters the catalog neither pinned nor vendored

Many published agent skills have no license file, which legally means all rights reserved.
Vendoring such a skill copies it without permission and pinning it redistributes it through our marketplace; the fact that a skill is a short Markdown file does not change that.
We therefore refuse both, and `/devkit:add-skill` instead drafts a request to the author for a license or for written permission to Lyngon, with a follow-up item in `docs/TODO.md` when the request is sent.
The cost is that useful skills stay out until their authors answer; the alternative is a catalog whose word "vetted" does not cover the one question a lawyer would ask first.
