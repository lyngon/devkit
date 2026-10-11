# domain-model

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream path**: `skills/engineering/domain-modeling`
- **Upstream name**: `domain-modeling`
- **Upstream version**: 1.2.3
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

The discipline of settling terms and recording decisions as they crystallise, feeding `CONCEPTS.md` and `docs/decisions/` in every Lyngon repository.

## Local patches

- Renamed `domain-modeling` to `domain-model`.
- `CONTEXT.md` is `CONCEPTS.md`; `CONTEXT-MAP.md` is a root `CONCEPTS.md` with a `## Contexts` section.
- Layout examples show a context's glossary and decision records in the package that owns the context instead of `src/<name>/`, with the Lyngon structure's core library named in a conditional section.
- `CONTEXT-FORMAT.md` is `CONCEPTS-FORMAT.md`; both format files are symlinks to the marketplace's `shared/` directory and can be overridden per repository from `docs/conventions/`.
- Dropped `agents/openai.yaml` (another agent's skill metadata).
- Reflowed to one sentence per line.
- 2026-10-11: upstream's ADRs are decision records. They live in `docs/decisions/`, the file trees name them after the decision without a number, and a record is offered by the admission test, which replaces upstream's three criteria (hard to reverse, surprising without context, a real trade-off). `ADR-FORMAT.md` is `DECISION-RECORD-FORMAT.md`, and the repository override is `docs/conventions/decision-record.md`. The format ends a record with an `Enforced by:` line, drops the `Status:` line, the change log and the rules for editing an accepted record, and has a record deleted when its decision changes or a check comes to carry it.

## Review notes

Pure prompt text, no scripts, no hooks, no tool restrictions.
