# discover

Discovery before building.

## Skills

- `/discover:brainstorm`: toss ideas around in conversation without writing anything: no rounds, no gate, no `CONCEPTS.md` entries, no decision records, no plan file. In-house. The agent invokes it on "brainstorm", "toss ideas around" and "think out loud".
- `/discover:approach [--no-docs]`: classify the work (spike, bounded, architectural), interview relentlessly on the architectural path, write `CONCEPTS.md` terms and decision records as they settle, write the design to `docs/plans/` and gate implementation on the user's approval. The agent invokes it before building anything with more than one reasonable design. `--no-docs` skips the terms and decision records.
- `interview`: the rounds-and-frontier interview method. Claude invokes it on "grill", "interview" and "challenge" phrasing.
- `domain-model`: settle terms into `CONCEPTS.md` and record decisions as decision records. Claude invokes it when terminology or decisions are being discussed.
- `/discover:why <question>`: answer why code, a design or a decision is the way it is, from the decision records (the deleted ones included), git, pull request bodies and issues, with every claim marked as found, inferred or unknown. The agent invokes it before changing code whose reason is not visible.

`approach`, `interview` and `domain-model` are vendored from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT); `approach` also carries text from [obra/superpowers](https://github.com/obra/superpowers) (MIT).
`why` is vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
The licenses are `LICENSE-mattpocock`, `LICENSE-superpowers` and `LICENSE-pstack` in this plugin.
The provenance records are [mattpocock.md](../../catalog/vendored/mattpocock.md), [superpowers.md](../../catalog/vendored/superpowers.md) and [pstack.md](../../catalog/vendored/pstack.md) under `catalog/vendored/`.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```
