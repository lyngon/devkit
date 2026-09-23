# discover

Discovery before building.

Prerequisites: documents

## Skills

- `/discover:brainstorm`: toss ideas around in conversation without writing anything: no rounds, no gate, no `CONCEPTS.md` entries, no ADRs, no plan file. In-house. The agent invokes it on "brainstorm", "toss ideas around" and "think out loud".
- `/discover:approach [--no-docs]`: classify the work (spike, bounded, architectural), interview relentlessly on the architectural path, write `CONCEPTS.md` terms and ADRs as they settle, write the design to `docs/plans/` and gate implementation on the user's approval. The agent invokes it before building anything with more than one reasonable design. `--no-docs` skips the terms and ADRs.
- `interview`: the rounds-and-frontier interview method. Claude invokes it on "grill", "interview" and "challenge" phrasing.
- `domain-model`: settle terms into `CONCEPTS.md` and record decisions as ADRs. Claude invokes it when terminology or decisions are being discussed.

`approach`, `interview` and `domain-model` are vendored from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT); `approach` also carries text from [obra/superpowers](https://github.com/obra/superpowers) (MIT). See each skill's `UPSTREAM.md`.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install discover@lyngon
```
