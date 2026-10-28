# devkit

Skills for maintaining the Lyngon devkit itself.
They only run inside the devkit repository.

## Skills

- `/devkit:add-skill <what>`: given a skill name, a URL, several paths of one upstream, or a description of a skill that should exist, either finds and vets existing third-party skills and installs them (a pinned plugin, or vendored skills under their concerns with one provenance record for the upstream), or designs a new in-house skill in an interview through `discover:interview` and creates it. Given a change of a design file under `docs/plans/`, it takes the names, the destinations and the proof owed from the change's row. It carries the change through its eval cases to the pull request, which `build:pull-request` opens. User-invoked.

Planned: `bump-skill` (compare what is vendored from one upstream with it and carry changes over) and `package` (zip skills for Claude.ai chat). See `docs/TODO.md`.

## Hooks

- `SessionStart` (`hooks/export-environment-to-eval-run.sh`): in a run of `claude plugin eval`, writes the PATH of the session to `$CLAUDE_ENV_FILE`, so that a shell command of the run finds the tools of the devenv shell that the run was started from.
  It writes each variable `EVAL_EXPORT_<NAME>` of the session there as `<NAME>` too, so that a case can give its commands a variable.
  It puts the directory that `EVAL_PREPEND_TO_PATH` names, relative to the working directory, in front of that PATH, so that a case can give its commands a stand-in for a tool such as `gh`.
  In any other session it does nothing.
  Why a run needs it is in the section "Evals" of the [root README](../../README.md#evals).

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install devkit@lyngon --scope project
```
