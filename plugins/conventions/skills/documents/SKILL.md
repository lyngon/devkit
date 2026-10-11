---
name: documents
description: Lyngon conventions for a repository's steering documents (INTENT.md, .claude/CLAUDE.md, the rule files under .claude/rules/, CONCEPTS.md) and for README.md, at the root and in packages. Invoke before writing or editing one of them.
user-invocable: false
paths:
  - "**/INTENT.md"
  - "**/CONCEPTS.md"
  - "**/README.md"
  - ".claude/CLAUDE.md"
  - ".claude/rules/*.md"
---

# Steering documents

A steering document states what the code cannot show, and an agent must follow it.
One test decides whether any text enters one:

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

| Path | Holds | Loaded |
| --- | --- | --- |
| `INTENT.md` at the root | Product, audiences, done, failure, non-goals, priorities, horizon | Every session, through the agent file |
| `.claude/CLAUDE.md` | One line, `@../INTENT.md` | Every session |
| `.claude/rules/<name>.md` | One repository principle, or one rule that has no check yet | At launch without `paths:`, otherwise when a matching file is read or edited |
| `CONCEPTS.md` | Terms | On demand |
| `docs/decisions/<name>.md` | One decision record | On demand |

## Rules

- No `AGENTS.md` exists anywhere, and no `CLAUDE.md` exists outside `.claude/` at the repository root.
- Nothing but the import line goes into `.claude/CLAUDE.md`. A principle is a rule file, and whatever a tool can decide is a check.
- The organization's principles are in no repository. They come from the devkit plugins and are never copied in.
- `README.md` is not a steering document. It says how to use the repository and links to `INTENT.md` instead of repeating it.
- A rule file is named after its principle in kebab-case. It holds that name as its heading, the statement in one or two sentences, then one sentence starting `Why:`. It carries a `paths:` field whenever the principle concerns part of the tree, such as one package.
- `INTENT.md` has the sections Product, For whom, Done means, Failure means, Non-goals and Horizon, stays within 50 lines, and changes only when the purpose changes.
- `INTENT.md` may have one more section, `## Priorities`, between `## Non-goals` and `## Horizon`, with each line of the form "X over Y". A line enters only after an owner answered a real question from an agent, so the section starts absent.
- `CONCEPTS.md` follows [CONCEPTS-FORMAT.md](CONCEPTS-FORMAT.md), and a decision record follows the `decision-record` conventions.
- A repository-specific convention too long for a rule file goes to `docs/conventions/<topic>.md`, and the message of its check or a rule file points there.

## Package documents

A package gets an `INTENT.md` only when it has its own audience, its own done or failure, or its own non-goals that the root does not state.
That file uses the root's section names and holds only the sections that differ.
No session loads it: it is read on demand, and the package's `README.md` links to it.

## With the Lyngon baseline

Checked by the `validate-documents`, `markdownlint` and `prose-lint` hooks.

## With the Lyngon structure

`validate-structure` checks that every app and library has a `README.md`.
