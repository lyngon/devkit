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

# run_tool_hook <plugin root> <tool> <tool input> [<keys of a subagent's call>]: run the plugin's
# PreToolUse hooks on the tool as a session does. Sets out, err, code.
run_tool_hook() {
  local plugin_root=$1 tool=$2 tool_input=$3 agent=${4:-'{}'} commands command
  commands=$(jq -r --arg tool "$tool" '.hooks.PreToolUse[]? | select(.matcher == $tool) | .hooks[].command' "$plugin_root/hooks/hooks.json")
  jq -n --arg tool "$tool" --argjson tool_input "$tool_input" --argjson agent "$agent" \
    '{session_id: "s", hook_event_name: "PreToolUse", tool_name: $tool, tool_input: $tool_input, tool_use_id: "t"} + $agent' >"$tmp/stdin"
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

call='{"description": "Explore the parser", "prompt": "Explain how the parser works.", "subagent_type": "general-purpose"}'
subagent='{"agent_id": "a4bfb540ff007c542", "agent_type": "general-purpose"}'
no_nested_subagent='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "A subagent starts no subagent of its own, since the report of that subagent can reach the lead instead of you. Do this work yourself, here, and put what it finds in your report."}}'

run_tool_hook "$root" Agent "$call"
check "the lead's Agent call: exits 0" equals "$code" 0
check "the lead's Agent call: prints nothing, so the call runs as it is" equals "$out$err" ""

run_tool_hook "$root" Agent "$call" "$subagent"
check "a subagent's Agent call: exits 0" equals "$code" 0
check "a subagent's Agent call: prints nothing on stderr" equals "$err" ""
check "a subagent's Agent call: refused, telling it to do the work itself" json_equals "$out" "$no_nested_subagent"

run_tool_hook "$copy" Agent "$call" "$subagent"
check "a subagent's Agent call, from the copy: refused" json_equals "$out" "$no_nested_subagent"

mode_matcher=$(yq --front-matter=extract '.hooks.PreToolUse[].matcher' "$root/skills/auto/SKILL.md")
mode_command=$(yq --front-matter=extract '.hooks.PreToolUse[].hooks[].command' "$root/skills/auto/SKILL.md")

check "the mode's hook matches the tools that write files" equals "$mode_matcher" "Edit|Write|NotebookEdit|Bash"

repository=$tmp/orders
outside_any_repository=$tmp/outside-any-repository
mkdir -p "$repository/.git" "$repository/.claude/worktrees/rename/src" "$outside_any_repository"
: >"$repository/.claude/worktrees/rename/.git"

no_repository_above() {
  local directory=$1
  while [[ $directory != / ]]; do
    [[ ! -e $directory/.git ]] || {
      echo "  $directory holds .git; run the test with a TMPDIR outside every repository"
      return 1
    }
    directory=$(dirname "$directory")
  done
}

check "the test's directory lies outside every repository" no_repository_above "$tmp"

run_mode_hook() {
  local tool=$1 tool_input=$2 agent=${3:-'{}'}
  jq -n --arg tool "$tool" --argjson tool_input "$tool_input" --argjson agent "$agent" --arg cwd "$repository" \
    '{session_id: "s", cwd: $cwd, hook_event_name: "PreToolUse", tool_name: $tool, tool_input: $tool_input, tool_use_id: "t"} + $agent' >"$tmp/stdin"
  code=0
  out=$(env -i PATH="$script_tools" CLAUDE_PLUGIN_ROOT="$root" "$tools/bash" -c "$mode_command" <"$tmp/stdin" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

refused() {
  jq -n --arg path "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "In /build:auto the lead writes no code, so it may not write \($path). Start a build:implementer delegate (subagent_type \"build:implementer\") with a brief that names the file, and review its diff. The lead writes, by any tool, only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it."}}'
}

run_lead_command() {
  run_mode_hook Bash "$(jq -n --arg command "$1" '{command: $command, description: "Run it"}')" "${@:2}"
}

refused_command() {
  jq -n --arg part "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "In /build:auto the lead writes no code, so it may not write through `\($part)`. Start a build:implementer delegate (subagent_type \"build:implementer\") with a brief that names the file, and review its diff. The lead writes, by any tool, only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it, and its command names such a file by a path without a variable or a substitution."}}'
}

for path in src/orders/pricing.py tests/test_pricing.py README.md src/orders/new/rounding.py; do
  run_mode_hook Write '{"file_path": "'"$repository/$path"'", "content": "x"}'
  check "the lead's Write of $path: exits 0" equals "$code" 0
  check "the lead's Write of $path: refused, naming the delegate" json_equals "$out" "$(refused "$repository/$path")"
done

run_mode_hook Edit '{"file_path": "'"$repository/src/orders/pricing.py"'", "old_string": ">", "new_string": ">="}'
check "the lead's Edit of src/orders/pricing.py: refused" json_equals "$out" "$(refused "$repository/src/orders/pricing.py")"

run_mode_hook NotebookEdit '{"notebook_path": "'"$repository/analysis.ipynb"'", "new_source": "x"}'
check "the lead's NotebookEdit of analysis.ipynb: refused" json_equals "$out" "$(refused "$repository/analysis.ipynb")"

worktree_file=$repository/.claude/worktrees/rename/src/client.py
run_mode_hook Edit '{"file_path": "'"$worktree_file"'", "old_string": "a", "new_string": "b"}'
check "the lead's Edit of a file in a worktree: refused" json_equals "$out" "$(refused "$worktree_file")"

lead_command_refused() {
  local label=$1 command=$2 part=$3
  run_lead_command "$command"
  check "the lead's command, $label: exits 0" equals "$code" 0
  check "the lead's command, $label: refused, naming the delegate" json_equals "$out" "$(refused_command "$part")"
}

lead_command_runs() {
  local label=$1 command=$2
  run_lead_command "$command"
  check "the lead's command, $label: exits 0" equals "$code" 0
  check "the lead's command, $label: prints nothing, so it runs" equals "$out$err" ""
}

lead_command_refused "sed -i on a test file" \
  "sed -i 's/price_line/line_price/' tests/test_pricing.py" "sed -i 's/price_line/line_price/' tests/test_pricing.py"
lead_command_refused "sed -i with a suffix and -e" \
  "sed -i.bak -e 's/>/>=/' src/orders/pricing.py" "sed -i.bak -e 's/>/>=/' src/orders/pricing.py"
lead_command_refused "sed --in-place on a file in a worktree" \
  "sed --in-place 's/a/b/' $worktree_file" "sed --in-place 's/a/b/' $worktree_file"
lead_command_refused "perl -pi" \
  "perl -pi -e 's/>/>=/' src/orders/pricing.py" "perl -pi -e 's/>/>=/' src/orders/pricing.py"
lead_command_refused "a heredoc into a new file" "cat > src/orders/rounding.py <<'EOF'
def round_price(price):
    return price
EOF" "> src/orders/rounding.py"
lead_command_refused "an append to README.md" \
  "echo '- 10 percent off from 10 items on' >> README.md" ">> README.md"
lead_command_refused "tee -a" \
  "printf 'x\n' | tee -a src/orders/pricing.py" "tee -a src/orders/pricing.py"
lead_command_refused "cp from tmp/ into the change" \
  "cp tmp/pricing.py src/orders/pricing.py" "cp tmp/pricing.py src/orders/pricing.py"
lead_command_refused "mv inside the change" \
  "mv src/orders/pricing.py src/orders/prices.py" "mv src/orders/pricing.py src/orders/prices.py"
lead_command_refused "rm" "rm tests/test_pricing.py" "rm tests/test_pricing.py"
lead_command_refused "touch" "touch src/orders/rounding.py" "touch src/orders/rounding.py"
lead_command_refused "sed -i through xargs" \
  "grep -rl price_line src | xargs sed -i 's/price_line/line_price/g'" "xargs sed -i 's/price_line/line_price/g'"
lead_command_refused "sed -i through find -exec" \
  "find src -name '*.py' -exec sed -i 's/a/b/' {} +" "find src -name '*.py' -exec sed -i 's/a/b/' {} +"
lead_command_refused "sed -i on a path in a variable" \
  "for f in src/orders/*.py; do sed -i 's/a/b/' \"\$f\"; done" "sed -i 's/a/b/' \"\$f\""
lead_command_refused "sed -i in a command substitution" \
  "git status --short && echo \"\$(sed -i 's/a/b/' src/orders/pricing.py)\"" "sed -i 's/a/b/' src/orders/pricing.py"

lead_command_runs "the full check" "devenv test"
lead_command_runs "the full check, its output kept under tmp/" "devenv test > tmp/check.log 2>&1"
lead_command_runs "git status and diff" "git status --short && git diff main...HEAD -- src"
lead_command_runs "git commit" "git commit -m 'fix(orders): give a line of 10 items the bulk discount'"
lead_command_runs "git restore of a file of the change" "git restore src/orders/pricing.py"
lead_command_runs "gh pr create with a body file" \
  "gh pr create --title 'fix(orders): give a line of 10 items the bulk discount' --body-file tmp/pull-request-body.md"
lead_command_runs "gh pr create with a body in a heredoc" "gh pr create --title 'fix(orders): x' --body \"\$(cat <<'EOF'
## Problem

> A line of 10 items > 9 items, and rm src/orders/pricing.py > README.md is text.
EOF
)\""
lead_command_runs "reading files" \
  "cat src/orders/pricing.py; sed -n '1,20p' tests/test_pricing.py; sed 's/>/>=/' src/orders/pricing.py | diff src/orders/pricing.py -"
lead_command_runs "grep and find" "grep -rn BULK src | head -5 && find src -name '*.py' -exec sed -n 1p {} +"
lead_command_runs "writes under tmp/" \
  "echo notes > tmp/notes.md && cp src/orders/pricing.py tmp/pricing.py && sed -i 's/a/b/' tmp/pricing.py && mv tmp/pricing.py tmp/prices.py && rm tmp/prices.py"
lead_command_runs "an append under docs/plans/" "printf '%s\n' '- step' >> docs/plans/2026-10-31-bulk-discount.md"
lead_command_runs "a write outside any repository" "echo x > $outside_any_repository/notes.md 2>/dev/null"
lead_command_runs "a command that does not parse as bash" "print -l \${(f)\"\$(ls)\"}"

run_lead_command "sed -i 's/>/>=/' src/orders/pricing.py" '{"agent_id": "a1", "agent_type": "build:implementer"}'
check "a delegate's sed -i of src/orders/pricing.py: exits 0" equals "$code" 0
check "a delegate's sed -i of src/orders/pricing.py: prints nothing, so it runs" equals "$out$err" ""

for path in "$repository/tmp/work-trace/fix-orders.md" "$repository/tmp/pull-request-body.md" \
  "$repository/docs/plans/2026-10-31-bulk-discount.md" "$repository/docs/mistakes/a-lead-wrote-a-fix.md" \
  "$outside_any_repository/notes.md"; do
  run_mode_hook Write '{"file_path": "'"$path"'", "content": "x"}'
  check "the lead's Write of ${path#"$tmp"/}: exits 0" equals "$code" 0
  check "the lead's Write of ${path#"$tmp"/}: prints nothing, so it runs" equals "$out$err" ""
done

run_mode_hook Edit '{"file_path": "'"$repository/src/orders/pricing.py"'", "old_string": ">", "new_string": ">="}' \
  '{"agent_id": "a1", "agent_type": "build:implementer"}'
check "a delegate's Edit of src/orders/pricing.py: exits 0" equals "$code" 0
check "a delegate's Edit of src/orders/pricing.py: prints nothing, so it runs" equals "$out$err" ""

stop_command=$(yq --front-matter=extract '.hooks.Stop[].hooks[].command' "$root/skills/auto/SKILL.md")
em_dash=$'—'
en_dash=$'–'

run_stop_hook() {
  local reply=$1 stop_hook_active=${2:-false}
  jq -n --arg reply "$reply" --argjson active "$stop_hook_active" --arg cwd "$repository" \
    '{session_id: "s", cwd: $cwd, hook_event_name: "Stop", stop_hook_active: $active, last_assistant_message: $reply}' >"$tmp/stdin"
  code=0
  out=$(env -i PATH="$script_tools" CLAUDE_PLUGIN_ROOT="$root" "$tools/bash" -c "$stop_command" <"$tmp/stdin" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

sent_back() {
  local quoted
  quoted=$(printf '> %s\n' "$@")
  jq -n --arg quoted "$quoted" '{decision: "block", reason: "The reply holds an em dash or an en dash, which the reply rules of /build:auto forbid, in these lines:\n\($quoted)\nWrite the whole reply again, with a comma, parentheses or a new sentence in place of each dash, put a quote that must keep its dash in code font, and change nothing else."}'
}

reply="The fix is committed.
There is no remote, so there is nothing to push $em_dash per build:pull-request, I report the branch.
1. \`7223821\` $en_dash the failing test."
run_stop_hook "$reply"
check "a reply with dashes: exits 0" equals "$code" 0
check "a reply with dashes: sent back, quoting each line with one" json_equals "$out" \
  "$(sent_back "There is no remote, so there is nothing to push $em_dash per build:pull-request, I report the branch." "1. \`7223821\` $en_dash the failing test.")"

run_stop_hook "$reply" true
check "a reply with dashes after the hook sent it back once: ends the turn" equals "$out$err" ""

run_stop_hook "The fix is committed, and there is nothing to push."
check "a reply without a dash: ends the turn" equals "$out$err" ""

run_stop_hook "The test printed this:
\`\`\`text
1 passed $em_dash 0.01s
\`\`\`
The flag \`--range=1${en_dash}9\` stays."
check "a reply whose dashes are all in code: ends the turn" equals "$out$err" ""

run_stop_hook "The test printed this:
~~~text
1 passed $em_dash 0.01s
\`\`\`
2 passed $em_dash 0.02s
~~~
The span \`\`a\`b $en_dash c\`\` stays."
check "a reply whose dashes are in a tilde fence and a span of two backticks: ends the turn" equals "$out$err" ""

run_stop_hook "\`\`\`text
1 passed
\`\`\`
After the block $em_dash a dash in prose."
check "a dash in prose after a closed fence: sent back" json_equals "$out" "$(sent_back "After the block $em_dash a dash in prose.")"

if ((failures > 0)); then
  echo "test-build-hooks: $failures failure(s)" >&2
  exit 1
fi
echo "test-build-hooks: ok"
