#!/usr/bin/env bash
# Exercise update-eval-histories.py against a throwaway checkout with one
# plugin, one eval case and its history: a record that the hook at head prints
# otherwise, one that it no longer prints at all, the same with a record
# hanging off it, and the check on each. Run through `devenv test`.
set -euo pipefail

program=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/update-eval-histories.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# --- Fixture helpers ---------------------------------------------------------

# new_checkout: a checkout whose plugin `one` greets on SessionStart, naming a
# file by its path, and prints nothing for a Bash call.
new_checkout() {
  local root plugin
  root=$(mktemp -d "$tmp/checkout.XXXXXX")
  plugin=$root/plugins/one
  mkdir -p "$plugin/.claude-plugin" "$plugin/hooks" "$plugin/evals/resumes"
  echo '{"name": "one"}' >"$plugin/.claude-plugin/plugin.json"
  cat >"$plugin/hooks/hooks.json" <<'EOF'
{"hooks": {
  "SessionStart": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh"}]}],
  "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/quiet.sh"}]}]
}}
EOF
  cat >"$plugin/hooks/greet.sh" <<'EOF'
#!/usr/bin/env bash
echo "Read $CLAUDE_PLUGIN_ROOT/notes.md first."
EOF
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"$plugin/hooks/quiet.sh"
  chmod +x "$plugin/hooks/greet.sh" "$plugin/hooks/quiet.sh"
  printf 'schema_version: "1.1"\nname: resumes\ncontext:\n  history_file: history.jsonl\n' >"$plugin/evals/resumes/case.yaml"
  echo "$root"
}

# history <checkout> <parent of the last record>: a session that greeted with
# an older text, ran a Bash call whose hook failed then, and got its result.
history() {
  local file=$1/plugins/one/evals/resumes/history.jsonl
  cat >"$file" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Read /recorded/devkit/plugins/one/old.md first.","stdout":"Read /recorded/devkit/plugins/one/old.md first.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"/recorded/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Read /recorded/devkit/plugins/one/old.md first.\n</system-reminder>"}]}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"/recorded/cwd"}
{"parentUuid":"b","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"Bash","input":{"command":"ls"}}]},"uuid":"c","sessionId":"x","cwd":"/recorded/cwd"}
{"parentUuid":"c","attachment":{"type":"hook_non_blocking_error","hookName":"PreToolUse:Bash","toolUseID":"t","hookEvent":"PreToolUse","stderr":"Failed with non-blocking status code: quiet.sh: no shfmt","exitCode":1,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/quiet.sh","durationMs":5},"type":"attachment","uuid":"d","sessionId":"x","cwd":"/recorded/cwd"}
EOF
  printf '{"parentUuid":"%s","type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":"notes.md"}]},"toolUseResult":{"stdout":"notes.md"},"uuid":"e","sessionId":"x","cwd":"/recorded/cwd"}\n' "$2" >>"$file"
  echo "$file"
}

# --- Assertions --------------------------------------------------------------

# The plugin root as the hook commands name it, unexpanded.
# shellcheck disable=SC2016  # the variable stays literal
root_variable='"${CLAUDE_PLUGIN_ROOT}"'

# run <arguments>: run the program. Sets out, the output of both streams, and code.
run() {
  code=0
  out=$(python3 "$program" "$@" 2>&1) || code=$?
}

check() {
  local label=$1
  shift
  if "$@"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    echo "  ${out//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

says() {
  grep -qF -- "$1" <<<"$out"
}

# --- Cases -------------------------------------------------------------------

root=$(new_checkout)
file=$(history "$root" c)
before=$(<"$file")
run --check "$root"
check "the check exits 1 on a history that is behind" test "$code" -eq 1
check "the check names the record whose text the hook no longer prints" \
  says "plugins/one/evals/resumes/history.jsonl:1: behind: $root_variable/hooks/greet.sh on SessionStart:startup exits 0 and prints \"Read /recorded/devkit/plugins/one/notes.md first.\" at head"
check "the check names the record of a hook that prints nothing at head" \
  says "plugins/one/evals/resumes/history.jsonl:4: behind: $root_variable/hooks/quiet.sh on PreToolUse:Bash prints nothing at head"
check "the check names the command that brings it up to date" says 'run update-eval-histories'
check "the check changes nothing" test "$(<"$file")" == "$before"

run "$root"
check "the update exits 0 when it can bring every record up to date" test "$code" -eq 0
check "the record holds what the hook prints at head, with the checkout as recorded" \
  test "$(jq -sr '.[0].attachment.stdout' "$file")" == "Read /recorded/devkit/plugins/one/notes.md first."
check "the record's content and reminder hold the same text" \
  test "$(jq -sr '.[0] | .attachment.content + "|" + .rendered[0].content' "$file")" == \
  "Read /recorded/devkit/plugins/one/notes.md first.|<system-reminder>
SessionStart:startup hook success: Read /recorded/devkit/plugins/one/notes.md first.
</system-reminder>"
check "the record of the hook that prints nothing is gone, and the others stay" \
  test "$(jq -sr 'map(.uuid) | join(" ")' "$file")" == "a b c e"
run --check "$root"
check "the check passes on the updated history" test "$code" -eq 0 -a -z "$out"

root=$(new_checkout)
file=$(history "$root" d)
before=$(<"$file")
run "$root"
check "the update exits 1 when a record that goes has another hanging off it" test "$code" -eq 1
check "the update names that record and asks for a new recording" \
  says "plugins/one/evals/resumes/history.jsonl:4: record the session again: $root_variable/hooks/quiet.sh on PreToolUse:Bash prints nothing at head that this record holds, and records hang off this one"
check "the update keeps that record" test "$(jq -sr 'map(.uuid) | join(" ")' "$file")" == "a b c d e"

if ((failures > 0)); then
  echo "update-eval-histories tests: $failures failed" >&2
  exit 1
fi
echo "update-eval-histories tests: ok"
