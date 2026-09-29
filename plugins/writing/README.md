# writing

Prose quality.

Prerequisites: git

## Skills

- `/writing:unslop`: edit prose to remove the patterns that mark text as machine-written and give it a voice. The agent invokes it whenever it writes or edits prose, before handing it over; also answers "unslop", "humanize", "make this sound human", "clean up this writing", "edit for voice" and "de-AI this text".

The deterministic half (no em or en dashes, no curly quotes) is the `prose-lint` git hook in the shared devenv module, which also checks commit messages.

Vendored from [poteto/noodle](https://github.com/poteto/noodle) (MIT), see the skill's `UPSTREAM.md`.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install writing@lyngon --scope project
```
