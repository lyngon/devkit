# Walk every state before fixing protocol text

Seed prompt for a fresh Claude Code session in the devkit repository.

This is a bounded change: no design file and no plan file.
Work on the branch `feat/protocol-fix-state-walk`.

## The problem

Some skill text defines a protocol: states, the events that move between them, and rules that must hold in every state (the owner gate protocol in `plugins/build/skills/delegate/references/owner-gates.md` is one).
A fix to one sentence of such text changes a transition, and every state the transition touches can break.
In the owner gates work (pull request #7, 2026-09-30), three fixes the controller dictated each introduced a new Important finding, found only by the next review cycle:

- A reconciliation rule for a resumed run ledgered a gated task complete from its record commit, skipping the evidence review and silencing an existing safeguard.
- A one-run guard sent the whole post-gate block to every fix dispatch, whose pin checks then failed by construction once the action had run, so every such dispatch would report BLOCKED.
- A start-step rule for an unforeseen gate raised by an evidence review dropped the only signal that the gated action had already run, inviting it to run again.

Each cost a full fix and review cycle on the most capable model.

## The change

Before a fix brief for protocol text is dispatched (a task fix round, an evidence-review fix, the final fix wave), the controller lists the states and paths the fix touches, and for each one checks that the fixed text still gives the right outcome and contradicts no other sentence.
The list goes into the fix brief, so the implementer and the scoped re-review check the same states.

Places to change, each with its vendored skill's `UPSTREAM.md` local patch, a `build` version bump and a `CHANGELOG.md` entry:

- `plugins/build/skills/delegate/SKILL.md`: the fix loop and the final review's fix wave.
- `plugins/build/skills/execute/SKILL.md`: its fix pass after the final review.
- `plugins/build/skills/delegate/references/re-review-prompt.md`: the re-reviewer checks the brief's state list, not only the findings.

Decide in the change how the controller recognizes protocol text (text that names states and transitions, or rules that hold across steps) without adding the walk to every one-line fix, and keep the rule to a few sentences.

Remove this file and its `docs/TODO.md` entry in the last commit.
