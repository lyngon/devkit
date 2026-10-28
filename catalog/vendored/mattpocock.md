# mattpocock

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream version**: 1.2.3
- **Upstream license**: MIT (see [LICENSE-mattpocock](../../shared/LICENSE-mattpocock))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

### `plugins/discover/skills/approach`

The owner's gate on a design: an interview that combines `interview` and `domain-model`, so that a design session writes its terms and decision records as it goes, and ends at the owner's approval of the design file.

### `plugins/discover/skills/domain-model`

The discipline of settling terms and recording decisions as they crystallise, feeding `CONCEPTS.md` and `docs/decisions/` in every Lyngon repository.

### `plugins/discover/skills/interview`

The rounds-and-frontier interview method is how Lyngon scopes work before building; `/repo:init` embeds the same method.

## What was taken

| Upstream path | Destination |
| --- | --- |
| `skills/engineering/grill-with-docs` | `plugins/discover/skills/approach` |
| `skills/engineering/domain-modeling` | `plugins/discover/skills/domain-model` |
| `skills/productivity/grilling` | `plugins/discover/skills/interview` |
| `skills/engineering/domain-modeling/CONTEXT-FORMAT.md` | `shared/CONCEPTS-FORMAT.md` |
| `skills/engineering/domain-modeling/ADR-FORMAT.md` | `shared/DECISION-RECORD-FORMAT.md` |

The two format documents came with `domain-modeling` and are recorded with it.
Their reason, their patches and their review notes are under `plugins/discover/skills/domain-model`.

## Local patches

### `plugins/discover/skills/approach`

Upstream's skill is two lines: a description and "Call the Skill tool twice, for "grilling" and "domain-modeling"."
Everything else in the skill is written by Lyngon.

- Renamed `grill-with-docs` to `approach`.
- Skill calls are namespaced (`discover:interview`, `discover:domain-model`) so they resolve inside this plugin.
- Added the `--no-docs` argument, replacing upstream's separate `grill-me` skill: only `discover:interview` runs, and no term or decision record is written.
- `disable-model-invocation: true` stays, as upstream has it, so that only the operator starts the skill, as `/discover:approach` with the request. The workflow design makes the skill the owner's gate on a design, which the agent must never open on its own.
- The description says what the skill does and that only the operator starts it, where upstream's is "A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go." Upstream's "ADR's and glossary" are decision records and `CONCEPTS.md`.
- Added what must hold when the skill ends, stated as outcomes, as the principle `prescribe-proof-not-steps` asks: the interview on what only the owner can settle, with what a run can answer looked up and not asked; terms and decisions written as they settle; the design file under `docs/plans/`, committed on a branch, holding the goal and what done means, the alternatives compared, the components and the proof owed; what outlives the work in a steering document; nothing else changed; and one question at the end, whether the owner approves.
- Added that changes the owner asks for go into the file before the question is asked again, that the approval ends the skill, and that the work then goes on under the standing instructions, and under `/build:auto` only when the operator starts it.
- Added a closing pointer to `discover:brainstorm`.
- Prose is reflowed to one sentence per line.

### `plugins/discover/skills/domain-model`

- Renamed `domain-modeling` to `domain-model`.
- `CONTEXT.md` is `CONCEPTS.md`; `CONTEXT-MAP.md` is a root `CONCEPTS.md` with a `## Contexts` section.
- Layout examples show a context's glossary and decision records in the package that owns the context instead of `src/<name>/`, with the Lyngon structure's core library named in a conditional section.
- `CONTEXT-FORMAT.md` is `CONCEPTS-FORMAT.md`; both format files are symlinks to the marketplace's `shared/` directory and can be overridden per repository from `docs/conventions/`.
- Dropped `agents/openai.yaml` (another agent's skill metadata).
- Reflowed to one sentence per line.
- 2026-10-11: upstream's ADRs are decision records. They live in `docs/decisions/`, the file trees name them after the decision without a number, and a record is offered by the admission test, which replaces upstream's three criteria (hard to reverse, surprising without context, a real trade-off). `ADR-FORMAT.md` is `DECISION-RECORD-FORMAT.md`, and the repository override is `docs/conventions/decision-record.md`. The format ends a record with an `Enforced by:` line, drops the `Status:` line, the change log and the rules for editing an accepted record, and has a record deleted when its decision changes or a check comes to carry it.

### `plugins/discover/skills/interview`

- Renamed `grilling` to `interview`.
- Description lists "interviewed" and "challenged" as triggers next to the upstream "grill" phrases.
- Each question carries a name of two or three words, where upstream numbers the questions, and the template of a round follows. The user answers under the name and a later round refers to it.
- Added the rule that a skipped question takes the recommended answer.
- Reflowed to one sentence per line.

## Review notes

### `plugins/discover/skills/approach`

Pure prompt text, no scripts, no hooks, no tool restrictions.

### `plugins/discover/skills/domain-model`

Pure prompt text, no scripts, no hooks, no tool restrictions.

### `plugins/discover/skills/interview`

Pure prompt text, no scripts, no hooks, no tool restrictions.
