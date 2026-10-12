# mattpocock

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream version**: 1.2.3
- **Upstream license**: MIT (see [LICENSE-mattpocock](../../shared/LICENSE-mattpocock))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

### `plugins/discover/skills/approach`

The entry point that combines `interview` and `domain-model`, so a design session writes its docs as it goes.

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

The list covers the whole skill, the text adapted from obra/superpowers included, in the order the patches were made.
[superpowers.md](superpowers.md) records that upstream, and its license is [LICENSE-superpowers](../../shared/LICENSE-superpowers).

- Renamed `grill-with-docs` to `approach`.
- Skill calls are namespaced (`discover:interview`, `discover:domain-model`) so they resolve inside this plugin.
- Added the `--no-docs` argument, replacing upstream's separate `grill-me` skill.
- 2026-09-23: the classification into spike, bounded and architectural work with its one-way ratchet, the approval gate, the design file with its self-review and user review, the "Design for isolation and clarity" and "Working in existing codebases" lists and the red-flags table are adapted from obra/superpowers `skills/brainstorming` at commit `5bf4e78011075bcfc0dc295f0724994cd123ee71` (MIT, see [LICENSE-superpowers](LICENSE-superpowers)).
- Removed `disable-model-invocation: true`.
  The repo plugin's session hook tells the agent to invoke this skill before building anything with more than one reasonable design, which the flag made impossible.
- Rewrote the description to say what the skill does (classify, interview, write terms and decision records, gate implementation) and when to use it, keeping the upstream "grill me" trigger and pointing tossing ideas around to `discover:brainstorm`.
- The two skill calls moved into step 1 of the architectural path; a spike or a bounded change does not run the full interview.
- Clarifying questions are asked in whole rounds in the `discover:interview` format, replacing superpowers' one question per message; a bounded change gets one round.
- The design goes to `docs/plans/YYYY-MM-DD-<slug>.md` under a `## Design` heading with fixed sections (goal, approach, components, data flow, error handling, testing, out of scope), replacing superpowers' `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`; the skill does not commit it, and the text says the file is transient and that purpose, rules, terms and decisions belong in the Lyngon documents.
- `writing-plans` became `build:plan`, invoked only when the build plugin is installed; otherwise the design file is handed over.
- `elements-of-style:writing-clearly-and-concisely` became `writing:unslop`, applied when the writing plugin is installed.
- The bounded path's "TDD applies" became `practice:tdd` when the practice plugin is installed, followed by `review:request` and `build:finish` when those plugins are installed, so the bounded flow ends where `WORKFLOW.md` says it does.
- Dropped superpowers' visual companion, its checklist and process graph, its "Establish shared understanding" section (the interview covers it), the "too simple to need approval" section (folded into the red flags), the "terminal states" paragraph and its references to `frontend-design` and `mcp-builder`, and the "approve after each section" rule (the user reviews the whole file).
- The red-flags table was trimmed from seven rows to six and the "approved the spike, so the follow-up is approved" row was dropped; its point is in the gate.
- "Your human partner" became "the user"; `<HARD-GATE>` became the heading "The gate"; em dashes were removed; prose was reflowed to one sentence per line.
- Added a closing pointer to `discover:brainstorm`.
- Added a pointer to `WORKFLOW.md`, the shared document that lays out the flow between skills; the file is a symlink into the devkit's `shared/`.
- Step 4 of the architectural path lets the first interview round open with the choice between approaches when that choice is the root of the design tree; step 5 then confirms the choice with the trade-offs stated. Superpowers always proposes approaches after the questions.
- The bounded path runs `review:request` before the pull request and `build:finish` to push the branch and open it, where it said "before merging" and "to integrate the branch".
- The self-review of the design file also checks that every value an implementer must use exactly is stated and every edge behaviour is named with its outcome, because a plan now copies them from the design and decides none.
- 2026-10-11: decisions go to `docs/decisions/` as decision records, where the text said ADRs and `docs/adr/`, and what outlives the design file belongs in the steering documents, where it said the Lyngon documents.

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
- Added the rules that question numbers continue across rounds and that a skipped question takes the recommended answer.
- Reflowed to one sentence per line.

## Review notes

### `plugins/discover/skills/approach`

Pure prompt text, no scripts, no hooks, no tool restrictions.

### `plugins/discover/skills/domain-model`

Pure prompt text, no scripts, no hooks, no tool restrictions.

### `plugins/discover/skills/interview`

Pure prompt text, no scripts, no hooks, no tool restrictions.
