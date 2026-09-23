---
name: documents
description: Lyngon conventions for the standard repository documents CLAUDE.md, AGENTS.md, CONCEPTS.md, INTENT.md and README.md, at the root and in packages. Background knowledge, loaded automatically while working on one of them.
user-invocable: false
paths:
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
  - "**/CONCEPTS.md"
  - "**/INTENT.md"
  - "**/README.md"
---

# Standard documents

Each file has one job.
Anything that fits two goes in the one whose audience needs it first, and the other links to it.

| File | Audience | Holds |
| --- | --- | --- |
| `INTENT.md` | Both | Why and for whom: product, audiences, done, failure, non-goals, horizon. Changes only when the purpose changes. |
| `README.md` | Humans | How to use: getting started, layout, contributing, license. |
| `CLAUDE.md` | Agents | How to work: checks, layout, conventions, where documents go, what not to touch. |
| `CONCEPTS.md` | Both | Terms only. What a thing is, never how it is implemented. |

## Rules

- `CLAUDE.md` is the source; `AGENTS.md` is a symlink to it. Never edit `AGENTS.md`, never turn it into a file.
- `CLAUDE.md` holds only what is specific to this repository or package. Organization-wide conventions come from the devkit plugins and are never copied in.
- A package's `CLAUDE.md`, `INTENT.md` and `README.md` hold only what differs from the root.
- `INTENT.md` stays under fifty lines and carries no stories, acceptance criteria or release plans; those go to the issue tracker.
- `CONCEPTS.md` follows [CONCEPTS-FORMAT.md](CONCEPTS-FORMAT.md): opinionated definitions, `_Avoid_` lists, no implementation details, no decisions. A repository with several contexts keeps the root file as a map and each context's glossary with the package that owns the context.
- `README.md` and `CLAUDE.md` link to `INTENT.md` and `CONCEPTS.md` in their first lines rather than repeating them.
- Decisions go to `docs/adr/`, deferred work to `docs/TODO.md`, and a repository-specific convention longer than a line to `docs/conventions/<topic>.md` with a one-line pointer in `CLAUDE.md`.
- The `README.md` layout tree shows only files that exist.

## With the Lyngon baseline

Checked by the `markdownlint` and `prose-lint` hooks.

## With the Lyngon structure

- The root `CLAUDE.md` names every package in one line each and says that the repository follows the Lyngon structure.
- Every app and library carries its own `CLAUDE.md`, `AGENTS.md`, `INTENT.md` and `README.md`; `validate-structure` checks the set.
