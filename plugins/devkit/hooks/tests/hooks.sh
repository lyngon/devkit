#!/usr/bin/env bash
# Exercise the devkit plugin's hook script: what it writes to the environment
# file in an eval run and outside one. zsh and bash read the file back, as
# Claude Code's Bash tool does before a command. Run through `devenv test`.
set -euo pipefail

hooks=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# --- Fixture helpers ---------------------------------------------------------

# The PATH of the session: the one tool the hook needs, behind two directories
# whose names a careless export would split or cut short.
tools=$tmp/tools
mkdir -p "$tools" "$tmp/with space" "$tmp/it's"
ln -s "$(command -v bash)" "$tools/bash"
session_path="$tmp/with space:$tmp/it's:$tools"

# run_hook [VAR=value]...: run the hook as a session does, with the PATH of
# the session and the given variables in its environment. Sets out, err, code.
run_hook() {
  code=0
  rm -f "$tmp/env-file.sh"
  out=$(env -i PATH="$session_path" HOME="$tmp" _=/usr/bin/env "$@" \
    "$hooks/export-path-to-eval-run.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

# The PATH of a command whose shell started with another PATH and then ran the
# environment file.
path_after_env_file() {
  env -i PATH=/replaced/by/the/shell "$(command -v "$1")" -c "source '$tmp/env-file.sh' && printf %s \"\$PATH\""
}

# --- Assertions --------------------------------------------------------------

check() {
  local label=$1
  shift
  if "$@"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

equals() {
  [[ "$1" == "$2" ]] || {
    echo "  expected: $2"
    echo "  actual:   $1"
    return 1
  }
}

# --- export-path-to-eval-run.sh ----------------------------------------------

run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh"
check "eval run: a command in zsh gets the PATH of the session" \
  equals "$(path_after_env_file zsh)" "$session_path"
check "eval run: a command in bash gets the PATH of the session" \
  equals "$(path_after_env_file bash)" "$session_path"
check "eval run: exits 0, adds nothing to the context and says what it did" \
  equals "$code|$out|$err" "0||devkit plugin: exported the PATH of the session to the shell commands of this eval run"

run_hook CLAUDE_ENV_FILE="$tmp/env-file.sh"
check "outside an eval run: writes no environment file" \
  test ! -e "$tmp/env-file.sh"
check "outside an eval run: exits 0 and prints nothing" \
  equals "$code|$out|$err" "0||"

run_hook CLAUDE_CODE_EVAL_CONFINED=1
check "eval run without an environment file: exits 0 and says why it exported nothing" \
  equals "$code|$out|$err" "0||devkit plugin: no PATH to export, because CLAUDE_ENV_FILE is not set"

if ((failures > 0)); then
  echo "devkit hooks tests: $failures failure(s)" >&2
  exit 1
fi
echo "devkit hooks tests: ok"
