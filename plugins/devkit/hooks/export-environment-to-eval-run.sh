#!/usr/bin/env bash
# SessionStart hook of the devkit plugin: in an eval run, writes the PATH of
# the session to $CLAUDE_ENV_FILE, which Claude Code runs before every Bash
# command. The session of a run inherits the PATH of the shell that started
# the run, so it holds the tools of the devenv shell, but a command does not
# get it: the harness hides the shell snapshot that would hand it over, and
# on NixOS the shell of a run falls back to the system's PATH. The harness
# sets CLAUDE_CODE_EVAL_CONFINED in the session of a run and nowhere else.
#
# The harness passes no other variable of the devenv shell on, and from a case
# only variables whose names start with EVAL_. So the hook also writes each
# variable EVAL_EXPORT_<NAME> of the session as <NAME>, which is how a case
# gives its commands a variable that a shipped script reads.
#
# EVAL_PREPEND_TO_PATH names a directory inside the project, relative to it,
# that goes in front of that PATH. That is how a case gives its commands a
# stand-in for a tool that would reach outside the run, such as the forge CLI,
# which its scaffold script copies into the working directory.
#
# The hook prints its lines on stderr and exits 0.
set -euo pipefail

[[ -n ${CLAUDE_CODE_EVAL_CONFINED-} ]] || exit 0

if [[ -z ${CLAUDE_ENV_FILE-} ]]; then
  echo "devkit plugin: no PATH to export, because CLAUDE_ENV_FILE is not set" >&2
  exit 0
fi

path=$PATH
if [[ -n ${EVAL_PREPEND_TO_PATH-} ]]; then
  if [[ $EVAL_PREPEND_TO_PATH =~ ^/|(^|/)\.\.(/|$) ]]; then
    echo "devkit plugin: left out EVAL_PREPEND_TO_PATH, because $EVAL_PREPEND_TO_PATH is no directory inside the project" >&2
  else
    path=${CLAUDE_PROJECT_DIR:-$PWD}/$EVAL_PREPEND_TO_PATH:$path
  fi
fi

{
  printf 'export PATH=%q\n' "$path"
  for carrier in "${!EVAL_EXPORT_@}"; do
    name=${carrier#EVAL_EXPORT_}
    if [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      printf 'export %s=%q\n' "$name" "${!carrier}"
    else
      echo "devkit plugin: left out $carrier, because $name is no name of a variable" >&2
    fi
  done
} >"$CLAUDE_ENV_FILE"
echo "devkit plugin: exported the PATH of the session to the shell commands of this eval run" >&2
