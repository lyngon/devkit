---
name: documents
description: Lyngon conventions for a repository's steering documents (INTENT.md, .claude/CLAUDE.md, the rule files under .claude/rules/, CONCEPTS.md) and for README.md, at the root and in packages. Invoke before writing or editing one of them.
user-invocable: false
paths:
  - "**/INTENT.md"
  - "**/CONCEPTS.md"
  - "**/README.md"
  - "**/.claude/CLAUDE.md"
  - ".claude/rules/*.md"
---

# Steering documents

A steering document states what the code cannot show, and an agent must follow it.
One test decides whether any text enters one:

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

| Path | Holds | Loaded |
| --- | --- | --- |
| `INTENT.md` | Product, audiences, done, failure, non-goals, priorities, horizon; in a package, only the sections that differ from the root's | Through the agent file beside it: at the root every session, in a package when an agent works on a file of the package |
| `.claude/CLAUDE.md`, the agent file | Only imports of the Markdown files directly in its directory, `@../INTENT.md` among them | At the root every session; in a package when an agent reads, writes or edits a file of the package |
| `.claude/rules/<name>.md` | One repository principle, or one rule that has no check yet | At launch without `paths:`, otherwise when a matching file is read or edited |
| `CONCEPTS.md` | Terms | On demand, unless the agent file of its directory imports it |
| `docs/decisions/<name>.md` | One decision record | On demand, and through `discover:why` |

## Rules

- No `AGENTS.md` exists anywhere, and a `CLAUDE.md` exists only directly in a `.claude/` directory, at the repository root or in a package.
- An agent file holds only lines of the form `@../<name>.md`, each naming a tracked Markdown file directly in the directory that holds its `.claude/`, such as `INTENT.md`, `CONCEPTS.md` or `README.md`.
- Every agent file holds the line `@../INTENT.md`. Other imports are allowed, and nothing writes one by default.
- An agent file holds no free text, at the root either. A principle goes into a rule file under `.claude/rules/`, with `paths:` when it concerns part of the tree.
- The organization's principles are in no repository. They come from the `principles` plugin, which the agent reads through `principles:index`, and are never copied in.
- `README.md` is not a steering document. It says how to use the repository and links to `INTENT.md` instead of repeating it.
- A rule file is named after its principle in kebab-case. It holds that name as its heading, the statement in one or two sentences, then one sentence starting `Why:`. It carries a `paths:` field whenever the principle concerns part of the tree, such as one package.
- `INTENT.md` has the sections Product, For whom, Done means, Failure means, Non-goals and Horizon, stays within 50 lines, and changes only when the purpose changes.
- `INTENT.md` may have one more section, `## Priorities`, between `## Non-goals` and `## Horizon`, with each line of the form "X over Y". A line enters only after an owner answered a real question from an agent, so the section starts absent.
- `CONCEPTS.md` follows [CONCEPTS-FORMAT.md](CONCEPTS-FORMAT.md), and a decision record follows the `decision-record` conventions.
- A repository-specific convention too long for a rule file goes to `docs/conventions/<topic>.md`, and the message of its check or a rule file points there.

## Package documents

A package gets an `INTENT.md` only when it has its own audience, its own done or failure, or its own non-goals that the root does not state.
That file uses the root's section names and holds only the sections that differ, and the package's `README.md` links to it.

A package with its own `INTENT.md` holds `.claude/CLAUDE.md`, with the line `@../INTENT.md`, and no other package holds an agent file.
Claude Code loads the agent file and the intent it imports when an agent reads, writes or edits a file of the package, and a session that works on no file of the package does not carry them.
An agent that changes the package only through the shell, or searches it only with Grep and Glob, does not load them.
A package with a `CONCEPTS.md` and no `INTENT.md` gets no agent file, and its glossary stays on demand.

## Checks

Checked by the `validate-documents`, `markdownlint` and `prose-lint` hooks.

## With the Lyngon structure

`validate-structure` checks that every app and library has a `README.md`.
