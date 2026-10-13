#!/usr/bin/env bash
# SessionStart hook of the devkit plugin: in an eval run, writes the PATH of
# the session to $CLAUDE_ENV_FILE, which Claude Code runs before every Bash
# command. The session of a run inherits the PATH of the shell that started
# the run, so it holds the tools of the devenv shell, but a command does not
# get it: the harness hides the shell snapshot that would hand it over, and
# on NixOS the shell of a run falls back to the system's PATH. The harness
# sets CLAUDE_CODE_EVAL_CONFINED in the session of a run and nowhere else.
# The hook prints at most one line, on stderr, and exits 0.
set -euo pipefail

[[ -n ${CLAUDE_CODE_EVAL_CONFINED-} ]] || exit 0

if [[ -z ${CLAUDE_ENV_FILE-} ]]; then
  echo "devkit plugin: no PATH to export, because CLAUDE_ENV_FILE is not set" >&2
  exit 0
fi

printf 'export PATH=%q\n' "$PATH" >"$CLAUDE_ENV_FILE"
echo "devkit plugin: exported the PATH of the session to the shell commands of this eval run" >&2
