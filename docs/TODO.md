# TODO

Deferred work the owner explicitly chose not to do yet.
One item per line, with the date it was deferred.

- 2026-09-15: Make the marketplace agent-agnostic (Codex, Cursor, Copilot) once a second agent is in use at Lyngon. Skill bodies are already written agent-neutral to keep this cheap.
- 2026-09-15: A `bump` workflow, and later a skill, for updating vendored catalog entries from upstream: copy, diff, update the catalog record.
- 2026-09-15: Evaluate Matt Pocock's plugin (<https://github.com/mattpocock/skills>) as a pinned catalog entry. Blocker: its `domain-modeling` skill writes `CONTEXT.md`, which fights our `CONCEPTS.md` convention in any repo that installs both.
