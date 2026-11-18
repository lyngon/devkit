#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: script-tools-on-hook-path.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
plugin_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
tmp=$(cd "$tmp" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
failures=0

tools_dir() {
  local dir=$tmp/tools-$1 tool
  shift
  mkdir -p "$dir"
  ln -s "$(command -v bash)" "$dir/bash"
  for tool in "$@"; do
    ln -s "$(PATH=$script_tools command -v "$tool")" "$dir/$tool"
  done
  echo "$dir"
}
no_tools=$(tools_dir none)
without_shfmt=$(tools_dir without-shfmt python3 pygmentize)
without_python3=$(tools_dir without-python3 shfmt pygmentize)
without_pygmentize=$(tools_dir without-pygmentize python3 shfmt)
python3_only=$(tools_dir python3-only python3)

tree=$tmp/repository
mkdir -p "$tree/.git" "$tree/apps/demo"
touch "$tree/devenv.nix"
plain=$tmp/plain
mkdir -p "$plain/.git"

command=$(jq -r '.hooks.SessionStart[].hooks[].command | select(contains("/hooks/script-tools-on-hook-path.sh"))' "$plugin_root/hooks/hooks.json")

run_hook() {
  code=0
  out=$(cd "$2" && env -i PATH="$1" HOME="$tmp" CLAUDE_PLUGIN_ROOT="$plugin_root" CLAUDE_PROJECT_DIR="$2" \
    "$no_tools/bash" -c "${command:-exit 99}" 2>"$tmp/stderr" <<<'{"hook_event_name":"SessionStart","source":"startup"}') || code=$?
  err=$(<"$tmp/stderr")
}

operator_message() {
  jq -r .systemMessage <<<"$out"
}

model_context() {
  jq -r '.hookSpecificOutput | "\(.hookEventName): \(.additionalContext)"' <<<"$out"
}

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

no_python_hook_runs="No Python hook of a plugin runs, and Claude Code goes on as if it did not exist, the build plugin's guard on OpenTofu commands that write included."
how_to_start="A session started from a shell where the repository's devenv environment is loaded runs them. In VS Code, close the window and open the repository with code . from such a shell, because the Claude Code extension keeps the first PATH it reads in a window."
missing_all="python3, shfmt and pygmentize are missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook. $no_python_hook_runs"

run_hook "$script_tools:$no_tools" "$tree"
check "the baseline's script tools on the PATH: nothing" equals "$code|$out|$err" "0||"

run_hook "$no_tools" "$tree"
check "no tool on the PATH: the operator reads which, what that turns off and how to start a session that runs them" \
  equals "$code|$(operator_message)|$err" "0|$missing_all $how_to_start|"
check "no tool on the PATH: the model reads the same and is told to pass it on" \
  equals "$(model_context)" "SessionStart: $missing_all Tell the operator in your first reply. $how_to_start"

run_hook "$without_python3" "$tree"
check "python3 missing, the others there: python3 alone is named" \
  equals "$(operator_message)" "python3 is missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook. $no_python_hook_runs $how_to_start"

run_hook "$without_shfmt" "$tree"
check "shfmt missing, the others there: shfmt is named, with what a hook that parses shell does without it" \
  equals "$(operator_message)" "shfmt is missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook. No hook can parse a shell command without shfmt, so the build plugin's guard on OpenTofu commands refuses each one that names tofu. $how_to_start"

run_hook "$without_pygmentize" "$tree"
check "pygmentize missing, the others there: pygmentize is named, with what the comment auditor's guard does without it" \
  equals "$(operator_message)" "pygmentize is missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook. No hook can tell comments from code without pygmentize, so the build plugin's guard on the comment auditor refuses each edit it makes inside a repository. $how_to_start"

run_hook "$python3_only" "$tree"
check "only python3 there: shfmt and pygmentize are named, with what each turns off" \
  equals "$(operator_message)" "shfmt and pygmentize are missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook. No hook can parse a shell command without shfmt, so the build plugin's guard on OpenTofu commands refuses each one that names tofu. No hook can tell comments from code without pygmentize, so the build plugin's guard on the comment auditor refuses each edit it makes inside a repository. $how_to_start"

run_hook "$no_tools" "$tree/apps/demo"
check "started in a directory of the repository: the same message" \
  equals "$(operator_message)" "$missing_all $how_to_start"

run_hook "$no_tools" "$plain"
check "a repository without a devenv.nix, which no devenv shell can fix: nothing" equals "$code|$out|$err" "0||"

if ((failures > 0)); then
  echo "script-tools-on-hook-path tests: $failures failure(s)" >&2
  exit 1
fi
echo "script-tools-on-hook-path tests: ok"
