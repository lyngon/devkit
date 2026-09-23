---
name: markdown
description: Lyngon Markdown writing conventions. Background knowledge, loaded automatically while working on Markdown files.
user-invocable: false
paths:
  - "**/*.md"
---

# Markdown conventions

- One sentence per line. Line length is not checked; the diff is what matters.
- No em dashes, no en dashes, no curly quotes. Commas, parentheses or a new sentence instead.
- Headings in sentence case, nested without skipping levels, never ending in punctuation.
- Every command on its own line in a fenced code block, never inline in a sentence.
- Every fenced block names its language, `text` when there is none.
- Links are relative paths inside the repository and full URLs in angle brackets outside it.
- Tables only for data that is tabular. Prose for everything else.
- Lists for parallel items; a single point or a line of argument stays in prose.
- Bold for the first words of a bullet at most, never a whole sentence, never a proper noun.
- No decorative emoji.
- Say who and what, not "it is important to note". Delete filler on sight.
- Before handing prose over, run `/writing:unslop` on it.

## With devenv

Checked by the `markdownlint`, `prose-lint` and `typos` hooks.
