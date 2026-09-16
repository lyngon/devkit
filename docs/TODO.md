# TODO

Deferred work the owner explicitly chose not to do yet.
One item per line, with the date it was deferred.

- 2026-09-15: Make the marketplace agent-agnostic (Codex, Cursor, Copilot) once a second agent is in use at Lyngon. Skill bodies are already written agent-neutral to keep this cheap.
- 2026-09-15: A compare flow, and later a skill, for vendored skills: diff the upstream skill between the recorded commit and the latest, decide what to carry over, update `UPSTREAM.md`.
- 2026-09-16: A `conventions` plugin for organization-wide coding and writing conventions (per language, styling), one skill per topic, loaded on demand through `paths` frontmatter so they reach every agent in every repository, including CI, without copies in each repository.
- 2026-09-16: Build a zip per skill as a release artifact (a devenv task run in CI), so skills can be uploaded to Claude.ai chat, which takes skill folders as zip files and has no plugin or marketplace support. Skills that call other skills by `plugin:name` or rely on Bash will need a note on what breaks there.
