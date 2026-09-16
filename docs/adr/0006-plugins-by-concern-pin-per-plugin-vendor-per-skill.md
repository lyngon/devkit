# Plugins are organized by concern; pinning is per plugin, vendoring is per skill

ADR 0002 separated third-party code into its own plugins under `plugins/third-party/`, which made origin, not purpose, the organizing principle.
We now organize every plugin by concern (`repo`, `discover`) and let a plugin hold in-house and vendored skills side by side, including vendored skills from different authors when they serve the same concern.
Claude Code can only pin whole plugins, so pinning stays plugin-level with a record in `catalog/`; vendoring becomes skill-level, with `UPSTREAM.md` and the upstream license next to the vendored `SKILL.md`.
The `sha` rule from ADR 0002 stays: pinned entries need a 40-character commit, vendored skills record one in `UPSTREAM.md`.

## Consequences

- In-house plugin names drop the `lyngon-` prefix; the marketplace name already namespaces them (`repo@lyngon`).
- A plugin's license is Apache-2.0 while individual skills inside it may be MIT; the per-skill `LICENSE` file satisfies the notice requirement.
- The validator can no longer tell vendored from in-house by path. It uses the presence of `UPSTREAM.md` and `LICENSE` in a skill directory, and rejects one without the other.
