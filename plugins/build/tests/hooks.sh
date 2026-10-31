#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: hooks.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
hooks=$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)
root=$(dirname "$hooks")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# --- Fixture helpers ---------------------------------------------------------

# The PATH of the session: the one tool the hook needs.
tools=$tmp/tools
mkdir -p "$tools"
ln -s "$(command -v bash)" "$tools/bash"

# run_hook <hooks directory>: run its hook as a session does. Sets out, err, code.
run_hook() {
  code=0
  out=$(env -i PATH="$tools" HOME="$tmp" "$1/session-start.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

run_tool_hook() {
  local plugin_root=$1 tool=$2 tool_input=$3 commands command
  commands=$(jq -r --arg tool "$tool" '.hooks.PreToolUse[]? | select(.matcher == $tool) | .hooks[].command' "$plugin_root/hooks/hooks.json")
  jq -n --arg tool "$tool" --argjson tool_input "$tool_input" \
    '{session_id: "s", hook_event_name: "PreToolUse", tool_name: $tool, tool_input: $tool_input, tool_use_id: "t"}' >"$tmp/stdin"
  code=0 out="" err=""
  while IFS= read -r command; do
    out+=$(env -i PATH="$script_tools" CLAUDE_PLUGIN_ROOT="$plugin_root" "$tools/bash" -c "$command" <"$tmp/stdin" 2>"$tmp/stderr") || code=$?
    err+=$(<"$tmp/stderr")
  done <<<"$commands"
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

json_equals() {
  local actual
  actual=$(jq -cS . <<<"$1" 2>&1) || actual="not JSON: $1"
  equals "$actual" "$(jq -cS . <<<"$2")"
}

# --- session-start.sh --------------------------------------------------------

text=$(<"$hooks/standing-instructions.txt")
mode_line="If the operator started this session with /build:auto and its text is no longer in your context, read <path>/skills/auto/SKILL.md before you continue."

check "the text names the mode's file through the placeholder" equals "${text##*$'\n'}" "$mode_line"

run_hook "$hooks"
check "in place: exits 0" equals "$code" 0
check "in place: prints nothing on stderr" equals "$err" ""
check "in place: prints the text with the plugin's root filled in" equals "$out" "${text//<path>/"$root"}"
check "in place: the mode's file it names exists" test -f "$root/skills/auto/SKILL.md"

copy="$tmp/a&b|c d/build"
mkdir -p "$copy"
cp -R "$hooks" "$copy/hooks"
run_hook "$copy/hooks"
check "copy: exits 0" equals "$code" 0
check "copy: the last line names the copy's file of the mode" equals "${out##*$'\n'}" "If the operator started this session with /build:auto and its text is no longer in your context, read $copy/skills/auto/SKILL.md before you continue."
check "copy: the rest of the text is unchanged" equals "${out%$'\n'*}" "${text%$'\n'*}"

call='{"description": "Fix the bug", "prompt": "Read the brief.", "subagent_type": "build:implementer"}'
foreground='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {"description": "Fix the bug", "prompt": "Read the brief.", "subagent_type": "build:implementer", "run_in_background": false}}}'

run_tool_hook "$root" Agent "$call"
check "Agent without run_in_background: exits 0" equals "$code" 0
check "Agent without run_in_background: prints nothing on stderr" equals "$err" ""
check "Agent without run_in_background: runs the call's input in the foreground" json_equals "$out" "$foreground"

run_tool_hook "$copy" Agent "$call"
check "Agent from the copy: runs the call's input in the foreground" json_equals "$out" "$foreground"

for value in true false; do
  run_tool_hook "$root" Agent '{"description": "Watch the build", "prompt": "Report when it ends.", "subagent_type": "general-purpose", "run_in_background": '"$value"'}'
  check "Agent with run_in_background $value: exits 0" equals "$code" 0
  check "Agent with run_in_background $value: prints nothing, so the call runs as it is" equals "$out$err" ""
done

if ((failures > 0)); then
  echo "test-build-hooks: $failures failure(s)" >&2
  exit 1
fi
echo "test-build-hooks: ok"
