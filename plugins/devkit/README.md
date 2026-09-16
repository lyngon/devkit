# devkit

Skills for maintaining the Lyngon devkit itself.
They only run inside the devkit repository.

## Skills

- `/devkit:add-skill <what>`: given a skill name, a URL, or a description of a skill that should exist, either finds and vets an existing third-party skill and installs it (pinned plugin or vendored skill under a concern), or designs a new in-house skill with `discover:approach` and creates it. User-invoked.

Planned: `bump-skill` (compare a vendored skill with upstream and carry changes over) and `package` (zip skills for Claude.ai chat). See `docs/TODO.md`.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install devkit@lyngon
```
