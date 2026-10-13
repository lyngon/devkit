---
name: how
description: Explore the codebase and explain how a subsystem, a feature or a flow works, as the architecture and runtime flow a senior engineer needs before working in it, with the files and functions to look at. Use for 'how does X work', a code walkthrough before changing code you do not know, and placement, ownership and layering questions ('where should this live', 'which package owns this', 'is this the right layer'). For why the code is the way it is, use discover:why. Not for a question that reading one function answers.
argument-hint: "<the question, naming the code, subsystem or flow it is about>"
---

# How

Explore the codebase to answer "how does X work?" questions.
Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Explorers and the explainer are subagents that inherit the session's model.
They read and search, and they change nothing.

## Assess complexity

If the scope is ambiguous, state your interpretation and explore.
The operator can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. One explainer explores and explains in a single pass. Go to "Explain directly".
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): spawn parallel explorers first, then hand off to the explainer. Go to "Explore".

When in doubt, take the simple path.

## Explore, for a complex question

Decompose the question into 2 to 4 exploration angles, each a distinct slice of the subsystem.
Spawn all explorers in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every finding is back before you go on.

Each explorer gets the prompt in `references/explorer-prompt.md` with its angle filled in.
Then go to "Synthesize".

## Explain directly, for a simple question

Spawn one subagent in the foreground (`run_in_background: false`) that explores and explains in one pass.

Build its prompt from `references/explainer-prompt.md` without the explorer-findings section.
Go to "Present".

## Synthesize, for a complex question

Once all explorers have returned, spawn one subagent in the foreground (`run_in_background: false`) to synthesize their findings into one explanation.

Build its prompt from `references/explainer-prompt.md` with every explorer's findings filled in.

## Present

Present the explainer's output to the operator.
Light edits for clarity or context from the conversation are fine.
Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key concepts, How it works, Where things live, Gotchas.
