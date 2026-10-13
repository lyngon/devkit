# writing

Prose quality.

## Skills

- `/writing:technical`: the standard a technical document is written to, in four layers: one Diátaxis mode per document, sentences that address the reader, one instruction per sentence, and no sentence that reads two ways. The agent invokes it when it writes or reviews docs, RFCs, READMEs, pull request descriptions or commit messages. It ends by applying `/writing:unslop`.
- `/writing:unslop`: edit prose to remove the patterns that mark text as machine-written and give it a voice. The agent invokes it whenever it writes or edits prose, before handing it over; also answers "unslop", "humanize", "make this sound human", "clean up this writing", "edit for voice" and "de-AI this text".
- `/writing:simpler`: restate the last message in plain words, shorter and without jargon. The agent invokes it when the reader did not follow and says so: "bro", "say that simpler", "in plain words", "no jargon".

The deterministic half (no em or en dashes, no curly quotes) is `prose-lint` in the shared devenv module: a git hook on Markdown files, and part of `check-pull-request` for the title and the body of a pull request.

`unslop` is vendored from [poteto/noodle](https://github.com/poteto/noodle) (MIT).
`technical` and `simpler` are vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
The licenses are `LICENSE-noodle` and `LICENSE-pstack` in this plugin.
The provenance records are [noodle.md](../../catalog/vendored/noodle.md) and [pstack.md](../../catalog/vendored/pstack.md) under `catalog/vendored/`.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole.
It is also the one plugin that stands alone: its text names no other plugin's skill and nothing of a development repository, which `validate-shipped-text` checks, so any other repository installs it on its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install writing@lyngon --scope project
```
