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
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Read ~/devkit/plugins/one/old.md first.","stdout":"Read ~/devkit/plugins/one/old.md first.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Read ~/devkit/plugins/one/old.md first.\n</system-reminder>"}]}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"b","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"Bash","input":{"command":"ls"}}]},"uuid":"c","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"c","attachment":{"type":"hook_non_blocking_error","hookName":"PreToolUse:Bash","toolUseID":"t","hookEvent":"PreToolUse","stderr":"Failed with non-blocking status code: quiet.sh: no shfmt","exitCode":1,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/quiet.sh","durationMs":5},"type":"attachment","uuid":"d","sessionId":"x","cwd":"~/cwd"}
EOF
  printf '{"parentUuid":"%s","type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":"notes.md"}]},"toolUseResult":{"stdout":"notes.md"},"uuid":"e","sessionId":"x","cwd":"~/cwd"}\n' "$parent_of_the_result" >>"$file"
  cat >>"$file" <<'EOF'
{"parentUuid":"e","attachment":{"type":"hook_success","hookName":"SessionStart:compact","toolUseID":"s2","hookEvent":"SessionStart","content":"Read ~/devkit/plugins/one/notes.md first.","stdout":"Read ~/devkit/plugins/one/notes.md first.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/greet.sh","durationMs":5},"type":"attachment","uuid":"f","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:compact hook success: Read ~/devkit/plugins/one/notes.md first.\n</system-reminder>"}]}
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
  says "plugins/one/evals/resumes/history.jsonl:1: behind: $unexpanded_plugin_root/hooks/greet.sh on SessionStart:startup exits 0 and prints \"Read ~/devkit/plugins/one/notes.md first.\" at head"
check "the check names the record of a hook that prints nothing at head" \
  says "plugins/one/evals/resumes/history.jsonl:4: behind: $unexpanded_plugin_root/hooks/quiet.sh on PreToolUse:Bash prints nothing at head"
check "the check names the command that brings it up to date" says 'run update-eval-histories'
check "a hook that left files behind prints on a later event what it printed on the first" \
  test "$(grep -c ': behind: ' <<<"$out")" -eq 2
check "the check changes nothing" test "$(<"$file")" == "$before"

run "$root"
check "the update exits 0 when it can bring every record up to date" test "$code" -eq 0
check "the record holds what the hook prints at head, with the checkout as recorded" \
  test "$(jq -sr '.[0].attachment.stdout' "$file")" == "Read ~/devkit/plugins/one/notes.md first."
check "the record's content and reminder hold the same text" \
  test "$(jq -sr '.[0] | .attachment.content + "|" + .rendered[0].content' "$file")" == \
  "Read ~/devkit/plugins/one/notes.md first.|<system-reminder>
SessionStart:startup hook success: Read ~/devkit/plugins/one/notes.md first.
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

write_eval_run_hook() {
  local checkout=$1 line=$2
  cat >"$checkout/plugins/one/hooks/hooks.json" <<'EOF'
{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/in-eval-run.sh"}]}]}}
EOF
  cat >"$checkout/plugins/one/hooks/in-eval-run.sh" <<EOF
#!/usr/bin/env bash
[[ -n \${CLAUDE_CODE_EVAL_CONFINED-} ]] || exit 0
echo "$line" >&2
EOF
  chmod +x "$checkout/plugins/one/hooks/in-eval-run.sh"
}

root=$(new_checkout)
write_eval_run_hook "$root" "one plugin: in an eval run"
cat >"$root/plugins/one/evals/resumes/history.jsonl" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"","stdout":"","stderr":"one plugin: in an eval run\n","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/in-eval-run.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"~/cwd"}
EOF
run --check "$root"
check "the check passes a history recorded in an eval run, with the record of a hook that prints only there" \
  test "$code:$out" == "0:update-eval-histories: ok, each history records what its hooks print at head (1 checked)"
write_eval_run_hook "$root" "one plugin: in an eval run, again"
run --check "$root"
check "the check names that record when the hook prints another line in an eval run at head" \
  says "plugins/one/evals/resumes/history.jsonl:1: behind: $unexpanded_plugin_root/hooks/in-eval-run.sh on SessionStart:startup exits 0 and prints \"one plugin: in an eval run, again\" at head"

root=$(new_checkout)
cat >"$root/plugins/one/hooks/hooks.json" <<'EOF'
{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/where.sh"}]}]}}
EOF
cat >"$root/plugins/one/hooks/where.sh" <<'EOF'
#!/usr/bin/env bash
if [[ $(cat) == *"\"cwd\":\"$PWD\""* ]]; then
  echo "Runs in $PWD, the directory that its input names."
else
  echo "Runs in $PWD, and its input names another directory."
fi
EOF
chmod +x "$root/plugins/one/hooks/where.sh"
file=$root/plugins/one/evals/resumes/history.jsonl
cat >"$file" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Runs in ~/cwd, the directory that its input names.","stdout":"Runs in ~/cwd, the directory that its input names.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/where.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Runs in ~/cwd, the directory that its input names.\n</system-reminder>"}]}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"~/cwd"}
EOF
run --check "$root"
check "a replayed hook gets the directory it runs in as its cwd, which its output names as ~/cwd" \
  test "$code:$out" == "0:update-eval-histories: ok, each history records what its hooks print at head (1 checked)"
before=$(jq -c '.cwd = "/recorded/cwd"' "$file")
echo "$before" >"$file"
run "$root"
check "the update refuses a history that names the working directory by a path that a run does not resolve" \
  test "$code" -eq 1
check "the refusal names the first such record and the path that resolves" \
  says "plugins/one/evals/resumes/history.jsonl:1: names the working directory \"/recorded/cwd\", and a history names it ~/cwd, the working directory of every run"
check "the refused history stays as it was" test "$(<"$file")" == "$before"

cat >"$file" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Runs in ~/cwd, the directory that its input names.","stdout":"Runs in ~/cwd, the directory that its input names.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/where.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Runs in ~/cwd, the directory that its input names.\n</system-reminder>"}]}
{"parentUuid":"a","attachment":{"type":"environment","snapshot":{"workingDirectory":"~/cwd","isWorktree":false,"isGitRepo":true,"additionalWorkingDirectories":[],"platform":"linux"}},"type":"attachment","uuid":"e","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\n# Environment\n - Primary working directory: ~/cwd\n</system-reminder>"}]}
{"parentUuid":"e","type":"user","message":{"role":"user","content":"List the files."},"uuid":"b","sessionId":"x","cwd":"~/cwd"}
EOF
before=$(<"$file")
run "$root"
check "the update refuses a history that holds the environment of the recording" test "$code" -eq 1
check "the refusal names that record and how to take it out" \
  says "plugins/one/evals/resumes/history.jsonl:2: holds an environment record, after which Claude Code tells a resumed agent that its working directory moved; delete the record, and give the record that hangs off it its parent"
check "the history with the environment record stays as it was" test "$(<"$file")" == "$before"

cat >"$file" <<'EOF'
{"parentUuid":null,"attachment":{"type":"hook_success","hookName":"SessionStart:startup","toolUseID":"s","hookEvent":"SessionStart","content":"Runs in ~/cwd, the directory that its input names.","stdout":"Runs in ~/cwd, the directory that its input names.\n","stderr":"","exitCode":0,"command":"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/where.sh","durationMs":5},"type":"attachment","uuid":"a","sessionId":"x","cwd":"~/cwd","rendered":[{"content":"<system-reminder>\nSessionStart:startup hook success: Runs in ~/cwd, the directory that its input names.\n</system-reminder>"}]}
{"parentUuid":"a","type":"user","message":{"role":"user","content":"Find the repository."},"uuid":"b","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"b","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"Bash","input":{"command":"find / -name orders"}}]},"uuid":"c","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"c","type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":"Command did not complete within its 120s timeout and was moved to the background (ID: bfind1234)."}]},"toolUseResult":{"stdout":"","stderr":"","interrupted":false,"backgroundTaskId":"bfind1234"},"uuid":"e","sessionId":"x","cwd":"~/cwd"}
{"parentUuid":"e","type":"user","message":{"role":"user","content":"<task-notification>\n<task-id>bfind1234</task-id>\n<tool-use-id>t</tool-use-id>\n<status>completed</status>\n<summary>Background command \"Find the repository\" completed (exit code 0)</summary>\n</task-notification>"},"origin":{"kind":"task-notification"},"uuid":"g","sessionId":"x","cwd":"~/cwd"}
EOF
before=$(<"$file")
run "$root"
check "the update refuses a history that holds a background command, also one whose completion it records" \
  test "$code" -eq 1
check "the refusal names the result of that command and how to take the command out" \
  says "plugins/one/evals/resumes/history.jsonl:4: holds the background command bfind1234, and a run resumes no background command of the recording; delete the call and its result, and give the record that hangs off each its parent"
check "the history with the background command stays as it was" test "$(<"$file")" == "$before"

if ((failures > 0)); then
  echo "update-eval-histories tests: $failures failed" >&2
  exit 1
fi
echo "update-eval-histories tests: ok"
