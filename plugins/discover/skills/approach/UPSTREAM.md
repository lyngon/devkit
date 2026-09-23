# approach

- **Upstream**: <https://github.com/mattpocock/skills>
- **Upstream path**: `skills/engineering/grill-with-docs`
- **Upstream name**: `grill-with-docs`
- **Upstream version**: 1.2.3
- **Upstream commit**: 3cca18b368ae95cdbdebbff572ccafa662551015
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-16 by Anders Åström

## Why it is here

The entry point that combines `interview` and `domain-model`, so a design session writes its docs as it goes.
Since 2026-09-23 it also carries the classification and approval gate from superpowers `brainstorming`, so every piece of work gets a design in the smallest form it needs before anything is built.

## Local patches

- Renamed `grill-with-docs` to `approach`.
- Skill calls are namespaced (`discover:interview`, `discover:domain-model`) so they resolve inside this plugin.
- Added the `--no-docs` argument, replacing upstream's separate `grill-me` skill.
- 2026-09-23: the classification into spike, bounded and architectural work with its one-way ratchet, the approval gate, the design file with its self-review and user review, the "Design for isolation and clarity" and "Working in existing codebases" lists and the red-flags table are adapted from obra/superpowers `skills/brainstorming` at commit `5bf4e78011075bcfc0dc295f0724994cd123ee71` (MIT, see [LICENSE-superpowers](LICENSE-superpowers)).
- Removed `disable-model-invocation: true`.
  The repo plugin's session hook tells the agent to invoke this skill before building anything with more than one reasonable design, which the flag made impossible.
- Rewrote the description to say what the skill does (classify, interview, write terms and ADRs, gate implementation) and when to use it, keeping the upstream "grill me" trigger and pointing tossing ideas around to `discover:brainstorm`.
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

## Review notes

Pure prompt text, no scripts, no hooks, no tool restrictions.

2026-09-23: the brainstorming text was reviewed against `shared/SKILL-REVIEW.md` before merging; pure prompt text, no scripts; its visual companion (a Node server that also fetches a logo from an external host) was left out.
Its `spec-document-reviewer-prompt.md` (a prompt for a reviewing subagent) was also left out; the self-review step replaces it.
