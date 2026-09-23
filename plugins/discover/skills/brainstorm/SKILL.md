---
name: brainstorm
description: >-
  Toss ideas around in conversation without writing anything: no interview rounds, no
  approval gate, no CONCEPTS.md entries, no ADRs, no plan file. Use when the user says
  brainstorm, toss ideas around, think out loud, just ideas or no docs, or wants to explore
  an idea without committing to it. Not when they ask for a design, a plan or a decision to
  record.
---

# Brainstorm

A conversation, not a process.
The only output is the conversation itself and, at the end, a short summary the user can copy.

## When to use

- The user says brainstorm, toss ideas around, think out loud, just ideas or no docs.
- The user wants to explore an idea without committing to it.

## When not to use

- A design is wanted: `discover:approach`.
- A term or a decision is to be recorded: `discover:domain-model`.
- A plan is wanted: `build:plan`.

## Workflow

1. Take the idea as given.
   Ask at most one clarifying question, and only if the idea cannot be discussed without it.
2. Argue back and offer alternatives.
   Name the strongest objection to each idea.
   No recommendation is required, but give one when asked.
3. Keep a running list of ideas in chat, marking kept and dropped ones as the conversation moves.
4. Write no files: no `CONCEPTS.md` entry, no ADR, no plan, and no `docs/TODO.md` entry unless the user says "defer that" in so many words.
   A deferred entry carries enough context to be picked up cold.
5. When an idea firms up and the user wants to pursue it, offer once to hand over to `discover:approach`.
   Do not invoke it on your own.
6. When the conversation ends, give a summary: ideas kept, ideas dropped and why, open questions.

Nothing said here is a decision until it has been through `discover:approach` or `discover:domain-model`.
