# domain-model

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream path**: `skills/engineering/domain-modeling`
- **Upstream name**: `domain-modeling`
- **Upstream version**: 1.2.3
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

The discipline of settling terms and recording decisions as they crystallise, feeding `CONCEPTS.md` and `docs/adr/` in every Lyngon repository.

## Local patches

- Renamed `domain-modeling` to `domain-model`.
- `CONTEXT.md` is `CONCEPTS.md`; `CONTEXT-MAP.md` is a root `CONCEPTS.md` with a `## Contexts` section.
- Layout examples show a context's glossary and ADRs in the package that owns the context instead of `src/<name>/`, with the Lyngon structure's core library named in a conditional section.
- `CONTEXT-FORMAT.md` is `CONCEPTS-FORMAT.md`; both format files are symlinks to the marketplace's `shared/` directory and can be overridden per repository from `docs/conventions/`.
- Dropped `agents/openai.yaml` (another agent's skill metadata).
- Reflowed to one sentence per line.

## Review notes

Pure prompt text, no scripts, no hooks, no tool restrictions.
