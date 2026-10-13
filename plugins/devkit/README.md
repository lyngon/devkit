# devkit

Skills for maintaining the Lyngon devkit itself.
They only run inside the devkit repository.

## Skills

- `/devkit:add-skill <what>`: given a skill name, a URL, several paths of one upstream, or a description of a skill that should exist, either finds and vets existing third-party skills and installs them (a pinned plugin, or vendored skills under their concerns with one provenance record for the upstream), or designs a new in-house skill with `discover:approach` and creates it. User-invoked.

Planned: `bump-skill` (compare what is vendored from one upstream with it and carry changes over) and `package` (zip skills for Claude.ai chat). See `docs/TODO.md`.

## Hooks

- `SessionStart` (`hooks/export-path-to-eval-run.sh`): in a run of `claude plugin eval`, writes the PATH of the session to `$CLAUDE_ENV_FILE`, so that a shell command of the run finds the tools of the devenv shell that the run was started from.
  In any other session it does nothing.
  Why a run needs it is in the section "Evals" of the [root README](../../README.md#evals).

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install devkit@lyngon --scope project
```
