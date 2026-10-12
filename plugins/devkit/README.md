# devkit

Skills for maintaining the Lyngon devkit itself.
They only run inside the devkit repository.

Prerequisites: documents, baseline, structure

## Skills

- `/devkit:add-skill <what>`: given a skill name, a URL, several paths of one upstream, or a description of a skill that should exist, either finds and vets existing third-party skills and installs them (a pinned plugin, or vendored skills under their concerns with one provenance record for the upstream), or designs a new in-house skill with `discover:approach` and creates it. User-invoked.

Planned: `bump-skill` (compare what is vendored from one upstream with it and carry changes over) and `package` (zip skills for Claude.ai chat). See `docs/TODO.md`.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install devkit@lyngon --scope project
```
