---
name: domain-model
description: Build and sharpen a repository's domain model. Use when discussing codebase terminology, writing or editing a CONCEPTS.md, or recording, editing or deleting a decision record.
---

# Domain modeling

Actively build and sharpen the repository's domain model as you design.
This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise.
Merely *reading* `CONCEPTS.md` for vocabulary is not this skill; that is a one-line habit any skill can do.
This skill is for when you are changing the model, not just consuming it.

## File structure

Most repositories have a single context:

```text
/
├── CONCEPTS.md
├── docs/
│   └── decisions/
│       ├── orders-are-event-sourced.md
│       └── postgres-holds-the-write-model.md
└── <packages>
```

If the root `CONCEPTS.md` has a `## Contexts` section, the repository has several contexts and the root file is a map pointing to where each one lives:

```text
/
├── CONCEPTS.md                       ← the map
├── docs/
│   └── decisions/                    ← repository-wide decisions
├── <package owning Ordering>/
│   ├── CONCEPTS.md
│   └── docs/decisions/               ← context-specific decisions
└── <package owning Billing>/
    ├── CONCEPTS.md
    └── docs/decisions/
```

### With the Lyngon structure

The package that owns a context is its core library, `libs/<ctx>/`; adapters and apps of the context have no glossary of their own.

Create files lazily: only when you have something to write.
If no `CONCEPTS.md` exists, create one when the first term is resolved.
If no `docs/decisions/` exists, create it when the first decision record is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONCEPTS.md`, call it out immediately.
"Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term.
"You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios.
Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees.
If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update CONCEPTS.md inline

When a term is resolved, update `CONCEPTS.md` right there.
Don't batch these up: capture them as they happen.
Use the format in [CONCEPTS-FORMAT.md](./CONCEPTS-FORMAT.md), unless the repository has `docs/conventions/concepts.md`, which overrides it.

`CONCEPTS.md` should be totally devoid of implementation details.
Do not treat it as a spec, a scratch pad, or a repository for implementation decisions.
It is a glossary and nothing else.

### Offer a decision record by the admission test

Offer to record a decision only when it passes this test:

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

If it does not pass, skip the record.
Use the format in [DECISION-RECORD-FORMAT.md](./DECISION-RECORD-FORMAT.md), unless the repository has `docs/conventions/decision-record.md`, which overrides it.
