# unslop

- **Upstream**: <https://github.com/poteto/noodle>
- **Upstream path**: `.agents/skills/unslop`
- **Upstream name**: `unslop`
- **Upstream version**: none declared (the skill ships inside the noodle application repository; noodle `VERSION` was 0.61.0 at the commit)
- **Upstream commit**: 82d2921c52370f23f29086de81ccfb600939c037
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

Lyngon documentation, READMEs and posts are drafted with agents and must read as written by a person.
This checklist names the tells concretely (25 patterns with examples) and adds a voice section, which the writing rules in CLAUDE.md files do not cover.
It is a single agent-neutral file with no dependencies.

## Local patches

- Removed every em dash from the skill's own text (pattern headings now use a colon, step 2 of the process is a sentence); the em dash pattern now also names en dashes.
- Added a paragraph to "Adding soul" scoping "Use I" and "Let some mess in" out of reference documents (READMEs, agent instruction files, glossaries, intent statements, ADRs, API docs), named generically so the plugin assumes nothing about the repository.
- Replaced the noodle-specific scheduler example in the colon pattern with a neutral setup-command example.
- Restarted the pattern numbering in each subsection (upstream counts 1 to 25 across headings), because markdownlint MD029 rejects a list that continues past a heading.
- Reflowed to one sentence per line and ended the process steps with full stops.
- Broadened the description from the six trigger phrases to "whenever writing or editing non-code text", so the skill fires proactively.
- Added `paths: ["**/*.md"]`, so the skill loads automatically whenever a Markdown file is read or edited.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-16.

- Security: none found. No network access, no credential reads, no scripts, hooks, `allowed-tools` or permission settings, no instruction hijacking, no encoded content, no writes.
- Quality: none found. Description states what and when; "unslop the README intro" triggers, "clean up this function" does not; body is 71 lines with no references; no dependencies; scope is "non-code text"; agent-neutral.
- Fit: the upstream text used em dashes itself (patched), a noodle-specific example (patched), and voice advice unsuited to reference documents (patched). Writes no devkit-owned files. Overlaps with the em dash rule in Lyngon CLAUDE.md files; complementary, not duplicated. No devkit skill covers prose editing.
- License: MIT at the repository root, no license inside the skill directory.
- Verdict: clear with patches, all applied.
