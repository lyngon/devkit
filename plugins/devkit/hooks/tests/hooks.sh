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
    "$hooks/export-environment-to-eval-run.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

# after_env_file <shell> <variable>: the value of the variable in a command
# whose shell started with another PATH and then ran the environment file, or
# "unset".
after_env_file() {
  env -i PATH=/replaced/by/the/shell "$(command -v "$1")" -c "source '$tmp/env-file.sh' && printf %s \"\${$2-unset}\""
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

# --- export-environment-to-eval-run.sh ---------------------------------------

run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh"
check "eval run: a command in zsh gets the PATH of the session" \
  equals "$(after_env_file zsh PATH)" "$session_path"
check "eval run: a command in bash gets the PATH of the session" \
  equals "$(after_env_file bash PATH)" "$session_path"
check "eval run: exits 0, adds nothing to the context and says what it did" \
  equals "$code|$out|$err" "0||devkit plugin: exported the PATH of the session to the shell commands of this eval run"

run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh" \
  EVAL_EXPORT_LIMIT_IN_DAYS="it's 365 days" EVAL_OTHER=kept-back
check "eval run: a variable named EVAL_EXPORT_<NAME> reaches a command in zsh as <NAME>" \
  equals "$(after_env_file zsh LIMIT_IN_DAYS)" "it's 365 days"
check "eval run: a variable named EVAL_EXPORT_<NAME> reaches a command in bash as <NAME>" \
  equals "$(after_env_file bash LIMIT_IN_DAYS)" "it's 365 days"
check "eval run: a variable of another name reaches no command" \
  equals "$(after_env_file zsh OTHER)" "unset"
check "eval run: the PATH of the session is exported beside the variable" \
  equals "$(after_env_file zsh PATH)" "$session_path"

run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh" EVAL_EXPORT_1ST=one EVAL_EXPORT_SECOND=two
check "eval run: a name that no shell can export is left out, and the others arrive" \
  equals "$(after_env_file zsh SECOND)" "two"
check "eval run: the name that was left out is on stderr" \
  equals "$code|$out|$err" "0||devkit plugin: left out EVAL_EXPORT_1ST, because 1ST is no name of a variable
devkit plugin: exported the PATH of the session to the shell commands of this eval run"

run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh" \
  CLAUDE_PROJECT_DIR="$tmp/with space" EVAL_PREPEND_TO_PATH=".git/forge/bin"
check "eval run: EVAL_PREPEND_TO_PATH puts that directory of the project in front of the PATH, in zsh" \
  equals "$(after_env_file zsh PATH)" "$tmp/with space/.git/forge/bin:$session_path"
check "eval run: EVAL_PREPEND_TO_PATH puts that directory of the project in front of the PATH, in bash" \
  equals "$(after_env_file bash PATH)" "$tmp/with space/.git/forge/bin:$session_path"

(cd "$tmp/it's" && run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh" EVAL_PREPEND_TO_PATH=bin)
check "eval run: without CLAUDE_PROJECT_DIR, EVAL_PREPEND_TO_PATH is a directory of the working directory" \
  equals "$(after_env_file zsh PATH)" "$tmp/it's/bin:$session_path"

for outside in "/usr/local/bin" "../bin" "bin/../../bin"; do
  run_hook CLAUDE_CODE_EVAL_CONFINED=1 CLAUDE_ENV_FILE="$tmp/env-file.sh" \
    CLAUDE_PROJECT_DIR="$tmp/with space" EVAL_PREPEND_TO_PATH="$outside"
  check "eval run: EVAL_PREPEND_TO_PATH=$outside leaves the PATH of the session as it is" \
    equals "$(after_env_file zsh PATH)" "$session_path"
  check "eval run: EVAL_PREPEND_TO_PATH=$outside is named on stderr" \
    equals "$code|$out|$err" "0||devkit plugin: left out EVAL_PREPEND_TO_PATH, because $outside is no directory inside the project
devkit plugin: exported the PATH of the session to the shell commands of this eval run"
done

run_hook CLAUDE_ENV_FILE="$tmp/env-file.sh" EVAL_EXPORT_LIMIT_IN_DAYS=365
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
