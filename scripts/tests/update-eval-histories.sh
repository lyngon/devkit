#!/usr/bin/env bash
set -euo pipefail

program=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/update-eval-histories.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

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
again=""
[[ ! -e $HOME/greeted && ! -e $CLAUDE_PLUGIN_DATA/greeted && ! -e greeted ]] || again=" Again."
mkdir -p "$HOME" "$CLAUDE_PLUGIN_DATA"
touch "$HOME/greeted" "$CLAUDE_PLUGIN_DATA/greeted" greeted
echo "Read $CLAUDE_PLUGIN_ROOT/notes.md first.$again"
EOF
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"$plugin/hooks/quiet.sh"
  chmod +x "$plugin/hooks/greet.sh" "$plugin/hooks/quiet.sh"
  printf 'schema_version: "1.1"\nname: resumes\ncontext:\n  history_file: history.jsonl\n' >"$plugin/evals/resumes/case.yaml"
  echo "$root"
}

write_history() {
  local checkout=$1 parent_of_the_result=$2
  local file=$checkout/plugins/one/evals/resumes/history.jsonl
  cat >"$file" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Read /recorded/devkit/plugins/one/old.md first.","stdout":"Read /recorded/devkit/plugins/one/old.md first.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"/recorded/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Read /recorded/devkit/plugins/one/old.md first.\n</system-reminder>"}]}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"/recorded/cwd"}
{"parentUuid":"b","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"Bash","input":{"command":"ls"}}]},"uuid":"c","sessionId":"x","cwd":"/recorded/cwd"}
{"parentUuid":"c","attachment":{"type":"hook_non_blocking_error","hookName":"PreToolUse:Bash","toolUseID":"t","hookEvent":"PreToolUse","stderr":"Failed with non-blocking status code: quiet.sh: no shfmt","exitCode":1,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/quiet.sh","durationMs":5},"type":"attachment","uuid":"d","sessionId":"x","cwd":"/recorded/cwd"}
EOF
  printf '{"parentUuid":"%s","type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":"notes.md"}]},"toolUseResult":{"stdout":"notes.md"},"uuid":"e","sessionId":"x","cwd":"/recorded/cwd"}\n' "$parent_of_the_result" >>"$file"
  cat >>"$file" <<'EOF'
{"parentUuid":"e","attachment":{"type":"hook_success","hookName":"SessionStart:compact","toolUseID":"s2","hookEvent":"SessionStart","content":"Read /recorded/devkit/plugins/one/notes.md first.","stdout":"Read /recorded/devkit/plugins/one/notes.md first.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh","durationMs":5},"type":"attachment","uuid":"f","sessionId":"x","cwd":"/recorded/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:compact hook success: Read /recorded/devkit/plugins/one/notes.md first.\n</system-reminder>"}]}
EOF
  echo "$file"
}

unexpanded_plugin_root="\"\${CLAUDE_PLUGIN_ROOT}\""

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

root=$(new_checkout)
file=$(write_history "$root" c)
before=$(<"$file")
run --check "$root"
check "the check exits 1 on a history that is behind" test "$code" -eq 1
check "the check names the record whose text the hook no longer prints" \
  says "plugins/one/evals/resumes/history.jsonl:1: behind: $unexpanded_plugin_root/hooks/greet.sh on SessionStart:startup exits 0 and prints \"Read /recorded/devkit/plugins/one/notes.md first.\" at head"
check "the check names the record of a hook that prints nothing at head" \
  says "plugins/one/evals/resumes/history.jsonl:4: behind: $unexpanded_plugin_root/hooks/quiet.sh on PreToolUse:Bash prints nothing at head"
check "the check names the command that brings it up to date" says 'run update-eval-histories'
check "a hook that left files behind prints on a later event what it printed on the first" \
  test "$(grep -c ': behind: ' <<<"$out")" -eq 2
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
  test "$(jq -sr 'map(.uuid) | join(" ")' "$file")" == "a b c e f"
run --check "$root"
check "the check passes on the updated history" \
  test "$code:$out" == "0:update-eval-histories: ok, each history records what its hooks print at head (1 checked)"

root=$(new_checkout)
file=$(write_history "$root" d)
before=$(<"$file")
run "$root"
check "the update exits 1 when a record that goes has another hanging off it" test "$code" -eq 1
check "the update names that record and asks for a new recording" \
  says "plugins/one/evals/resumes/history.jsonl:4: needs a new recording: $unexpanded_plugin_root/hooks/quiet.sh on PreToolUse:Bash prints nothing at head that this record holds, and records hang off this one"
check "the update keeps that record" test "$(jq -sr 'map(.uuid) | join(" ")' "$file")" == "a b c d e f"

if ((failures > 0)); then
  echo "update-eval-histories tests: $failures failed" >&2
  exit 1
fi
echo "update-eval-histories tests: ok"
