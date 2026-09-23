# discover

Discovery before building.

Prerequisites: documents

## Skills

- `/discover:approach [--no-docs]`: a relentless interview that sharpens a plan or design and writes `CONCEPTS.md` terms and ADRs as they settle. User-invoked. `--no-docs` skips the docs.
- `interview`: the rounds-and-frontier interview method. Claude invokes it on "grill", "interview" and "challenge" phrasing.
- `domain-model`: settle terms into `CONCEPTS.md` and record decisions as ADRs. Claude invokes it when terminology or decisions are being discussed.

All three are vendored from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT), see each skill's `UPSTREAM.md`.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install discover@lyngon
```
