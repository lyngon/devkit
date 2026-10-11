# Encode lessons in structure

Encode recurring fixes in mechanisms (tools, code, metadata, automation) instead of textual instructions.
Every error, human correction, and unexpected outcome is a learning signal.
Capture it, route it, and close the loop.

**Why:** Textual instructions are easy to miss.
They require the reader to notice, remember, and comply.
Structural mechanisms (lint rules, metadata flags, runtime checks, automation scripts) enforce the rule without cooperation.

**Pattern:**
When you catch yourself writing the same instruction a second time:

1. Ask: can this be a lint rule, a metadata flag, a runtime check, or a script?
2. If yes, encode it. Delete the instruction
3. If no (requires judgment), make it a principle and name the failure it prevents

**Pick the strongest mechanism.** When more than one mechanism would work, choose the strongest the situation allows (an unrepresentable state that cannot compile, then a lint or banned API that fails CI, then a canonical helper, then a runtime check), because agents copy whatever the surrounding code already does and a weaker guard becomes the next template.

**Corollary:** If the fix is structural, only use the structural fix.
The instruction is the symptom.
A rule without a check is debt.

**Feedback loop:**

- **Capture every correction.** When the owner or the operator intervenes or tests fail, decide if it's a one-off or a pattern.
- **Route to the right layer.** A first occurrence is noted in the pull request. A repeat gets the strongest check that works. A repeat that no tool can decide becomes a principle, which in a repository is a file under `.claude/rules/`.
- **Close the loop.** Don't just record. Apply now, or file an issue with the evidence.

**Anti-patterns:**

- Acknowledging without recording ("I'll keep that in mind" does not persist)
- Recording without routing (a note about a lint rule that should exist is wasted unless the lint rule gets implemented)
- Fixing without generalizing (fixing one instance while leaving the recurring pattern intact)
