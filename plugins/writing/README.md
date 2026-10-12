# writing

Prose quality.

## Skills

- `/writing:unslop`: edit prose to remove the patterns that mark text as machine-written and give it a voice. The agent invokes it whenever it writes or edits prose, before handing it over; also answers "unslop", "humanize", "make this sound human", "clean up this writing", "edit for voice" and "de-AI this text".

The deterministic half (no em or en dashes, no curly quotes) is `prose-lint` in the shared devenv module: a git hook on Markdown files, and part of `check-pull-request` for the title and the body of a pull request.

Vendored from [poteto/noodle](https://github.com/poteto/noodle) (MIT).
The license is `LICENSE-noodle` in this plugin, and the provenance record is [catalog/vendored/noodle.md](../../catalog/vendored/noodle.md).

## Install

Part of the `all` bundle, which a Lyngon repository installs whole.
It is also the one plugin that stands alone: its text names no other plugin's skill and nothing of a development repository, which `validate-shipped-text` checks, so any other repository installs it on its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install writing@lyngon --scope project
```
