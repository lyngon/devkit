#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: one-session-per-tree.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
plugin_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
tmp=$(cd "$tmp" && pwd -P)
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0
declare -A pid=()

declare -A terminal=()

kill_session() {
  kill -9 "${pid[$1]}" 2>/dev/null || true
  while [[ -e /proc/${pid[$1]} ]]; do
    sleep 0.01
  done
}

stop_sessions() {
  local name
  for name in "${!pid[@]}"; do
    kill_session "$name"
  done
}

close_terminals() {
  local name
  for name in "${!terminal[@]}"; do
    kill -9 "${terminal[$name]}" 2>/dev/null || true
  done
}
trap 'stop_sessions; close_terminals; rm -rf "$tmp"' EXIT

config=$tmp/config
registry=$config/sessions
mkdir -p "$registry"

main=$tmp/repo
shared=$main/.claude/worktrees/shared
git init -q -b main "$main"
git -C "$main" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -q --allow-empty -m base
git -C "$main" worktree add -q -b worktree-shared "$shared"

session_script=$tmp/session.sh
cat >"$session_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec 3<>"$1/requests"
while read -r command <&3; do
  code=0
  env -i PATH="$SCRIPT_TOOLS" HOME="$TEST_HOME" CLAUDE_CONFIG_DIR="$TEST_CONFIG" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    "$BASH" -c "$command" <"$1/input" >"$1/out" 2>"$1/err" || code=$?
  echo "$code" >"$1/done"
done
EOF
export SCRIPT_TOOLS=$script_tools TEST_HOME=$tmp TEST_CONFIG=$config PLUGIN_ROOT=$plugin_root
export SESSION_SCRIPT=$session_script

terminal_script=$tmp/terminal.sh
cat >"$terminal_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tty >"$1/name" || true
exec 3<>"$1/requests"
while read -r directory files <&3; do
  cd "$directory"
  bash "$SESSION_SCRIPT" "$files" &
  echo "$!" >"$1/started"
done
EOF

on_a_new_terminal='
import os, pty, sys
pid, master = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
try:
    while os.read(master, 4096):
        pass
except OSError:
    pass
os.waitpid(pid, 0)
'

open_terminal() {
  local files=$tmp/terminals/$1
  mkdir -p "$files"
  mkfifo "$files/requests" "$files/started"
  if [[ $1 == none ]]; then
    setsid bash "$terminal_script" "$files" &
  else
    python3 -c "$on_a_new_terminal" bash "$terminal_script" "$files" &
  fi
  terminal[$1]=$!
}
open_terminal none
open_terminal pty

hook_command() {
  jq -r --arg event "$1" --arg tool "${2-}" '.hooks[$event][]
    | select($event != "PreToolUse" or (.matcher as $matcher | $tool | test("^(" + $matcher + ")$")))
    | .hooks[].command | select(contains("/hooks/one-session-per-tree.py"))' "$plugin_root/hooks/hooks.json"
}

# Field <number> of /proc/<pid>/stat as proc(5) numbers it, counted after the
# command name in parentheses, which may hold spaces.
stat_field() {
  local stat fields
  stat=$(<"/proc/$1/stat")
  read -ra fields <<<"${stat##*") "}"
  echo "${fields[$2 - 3]}"
}

process_start_in_clock_ticks_after_boot() {
  stat_field "$1" 22
}

process_state() {
  stat_field "$1" 3
}

idle_seconds_shown_as_2_h_5_min=$(((2 * 60 + 5) * 60 + 30))

register() {
  local id=${pid[$1]} since=$((${EPOCHREALTIME/./} / 1000 - idle_seconds_shown_as_2_h_5_min * 1000))
  jq -n --argjson pid "$id" --arg name "$1" --arg entrypoint "$2" --arg status "$3" \
    --arg start "${4:-$(process_start_in_clock_ticks_after_boot "$id")}" --arg cwd "$(readlink "/proc/$id/cwd")" --argjson since "$since" \
    '{pid: $pid, sessionId: "id-\($name)", cwd: $cwd, startedAt: $since, procStart: $start, kind: "interactive",
      entrypoint: $entrypoint, name: $name, nameSource: "user", status: $status, statusUpdatedAt: $since}' \
    >"$registry/$id.json"
}

wait_out_a_10_ms_clock_tick_of_the_start_time() {
  sleep 0.03
}

start_session() {
  local files=$tmp/sessions/$1 on=$tmp/terminals/${5:-none}
  wait_out_a_10_ms_clock_tick_of_the_start_time
  mkdir -p "$files"
  mkfifo "$files/requests" "$files/done"
  echo "$2 $files" >"$on/requests"
  pid[$1]=$(<"$on/started")
  register "$1" "$3" "$4"
}

stop_session() {
  kill -STOP "${pid[$1]}"
  until [[ $(process_state "${pid[$1]}") == T ]]; do
    sleep 0.01
  done
}

run_hook() {
  local files=$tmp/sessions/$1
  jq -n --arg event "$2" --arg detail "${3-}" '{session_id: "id", hook_event_name: $event}
    + if $event == "PreToolUse" then {tool_name: $detail, tool_input: {command: "git status"}}
      else {source: (if $detail == "" then "startup" else $detail end)} end' \
    >"$files/input"
  hook_command "$2" "${3-}" >"$files/requests"
  code=$(<"$files/done") out=$(<"$files/out") err=$(<"$files/err")
}

next_case() {
  stop_sessions
  pid=()
  rm -rf "$tmp/sessions" "${registry:?}"/*
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

decision() {
  jq -r '.hookSpecificOutput | "\(.hookEventName) \(.permissionDecision)\n\(.permissionDecisionReason)"' <<<"$out"
}

verdict() {
  if [[ $(decision | head -n 1) == "PreToolUse deny" ]]; then echo refused; else echo allowed; fi
}

on_screen() {
  jq -r '.systemMessage' <<<"$out"
}

model_asked_to_tell() {
  jq -r '.hookSpecificOutput.hookEventName == "SessionStart"
    and .hookSpecificOutput.additionalContext == .systemMessage + "\nTell the operator in your first reply."' <<<"$out"
}

refused="Two sessions in one working tree change its HEAD, its index and its files under each other, so the repo plugin refuses this session's edits and shell commands here until this session has moved to a worktree of its own or that session has ended."
why="$refused Every other tool still works, Read, EnterWorktree and ExitWorktree among them. The standing instructions at the start of this session ask for this move, so it counts as the operator asking for each call below."

check "hooks.json runs the check before Edit, Write, NotebookEdit, Bash and Monitor, and at session start" \
  equals "$(for tool in Edit Write NotebookEdit Bash Monitor Read EnterWorktree ExitWorktree Agent; do echo "$tool $(hook_command PreToolUse "$tool" | wc -l)"; done | tr '\n' ' ')$(hook_command SessionStart | wc -l)" \
  "Edit 1 Write 1 NotebookEdit 1 Bash 1 Monitor 1 Read 0 EnterWorktree 0 ExitWorktree 0 Agent 0 1"

next_case
start_session earlier "$main" claude-vscode idle
start_session later "$main" cli busy
run_hook later PreToolUse Bash
check "the main checkout, the later session: refused, with the earlier session, the tree, its branch and a move by EnterWorktree" \
  equals "$code|$err|$(decision)" "0||PreToolUse deny
The Claude Code session \"earlier\" (pid ${pid[earlier]}, a VS Code session, idle for 2 h 5 min) works in this working tree, $main, which has the branch main checked out, and started before this session.
$why
- If your task continues the work on the branch main, ask the operator to close the session \"earlier\", and carry on here once it has ended.
- Otherwise, call EnterWorktree without a name, so that it creates a new worktree under a name it generates, since a name in use would enter that worktree, and carry on there. If EnterWorktree answers that this session is in a worktree session already, call ExitWorktree with action keep first, never remove, because the other session works in it."
run_hook earlier PreToolUse Edit
check "the main checkout, the earlier session: allowed, and nothing said" equals "$code|$out|$err" "0||"

next_case
start_session in-main "$main" cli idle
start_session first "$shared" sdk-cli busy
start_session second "$shared" cli busy
run_hook first PreToolUse Write
check "a linked worktree inside the main checkout, the earlier session there: allowed, whoever works in the main checkout" \
  equals "$code|$out|$err" "0||"
run_hook second PreToolUse Write
check "a linked worktree, the later session: refused, with the worktree and its branch" \
  equals "$code|$err|$(decision | sed -n '1,2p;4p')" "0||PreToolUse deny
The Claude Code session \"first\" (pid ${pid[first]}, a headless session, busy) works in this working tree, $shared, which has the branch worktree-shared checked out, and started before this session.
- If your task continues the work on the branch worktree-shared, ask the operator to close the session \"first\", and carry on here once it has ended."

next_case
start_session one "$main" cli idle
start_session two "$main/.claude" claude-vscode busy
start_session three "$main" cli busy
run_hook three PreToolUse Monitor
check "two earlier sessions in the tree, one of them in a directory below its root: both named" \
  equals "$(decision | sed -n '2p;4,5p')" \
  "The Claude Code sessions \"one\" (pid ${pid[one]}, a CLI session, idle for 2 h 5 min) and \"two\" (pid ${pid[two]}, a VS Code session, busy) work in this working tree, $main, which has the branch main checked out, and started before this session.
- If your task continues the work on the branch main, ask the operator to close the sessions \"one\" and \"two\", and carry on here once they have ended.
- Otherwise, call EnterWorktree without a name, so that it creates a new worktree under a name it generates, since a name in use would enter that worktree, and carry on there. If EnterWorktree answers that this session is in a worktree session already, call ExitWorktree with action keep first, never remove, because the other sessions work in it."

next_case
start_session earlier "$main" cli idle
start_session later "$main" cli busy
stop_session earlier
run_hook later PreToolUse Bash
check "an earlier session stopped as a job, its entry still idle: the refusal calls it stopped" \
  equals "$(decision | sed -n 2p)" "The Claude Code session \"earlier\" (pid ${pid[earlier]}, a CLI session, stopped) works in this working tree, $main, which has the branch main checked out, and started before this session."
run_hook later SessionStart
check "the same at session start, without a terminal: on screen, kill -KILL ends it" \
  equals "$code|$err|$(on_screen)" "0||The Claude Code session \"earlier\" (pid ${pid[earlier]}, a CLI session, stopped) works in this working tree, $main, which has the branch main checked out, and started before this session.
$refused
\"earlier\" is stopped, so a plain kill leaves it stopped, and kill -KILL ${pid[earlier]} ends it."
run_hook later SessionStart resume
check "the same at a resume, which starts in the tree it was launched in: nothing said" equals "$code|$out|$err" "0||"

next_case
start_session earlier "$shared" claude-vscode idle
start_session later "$shared" cli busy
run_hook later SessionStart
check "session start beside an earlier session that runs: on screen and to the model, kill ends it" \
  equals "$code|$err|$(on_screen)|$(model_asked_to_tell)" "0||The Claude Code session \"earlier\" (pid ${pid[earlier]}, a VS Code session, idle for 2 h 5 min) works in this working tree, $shared, which has the branch worktree-shared checked out, and started before this session.
$refused
kill ${pid[earlier]} ends \"earlier\".|true"

terminal_name=$(<"$tmp/terminals/pty/name")

next_case
start_session earlier "$main" cli idle pty
start_session later "$main" cli busy pty
stop_session earlier
run_hook later SessionStart
check "session start beside a stopped job of a shell on this terminal: fg there once this session has ended" \
  equals "$(on_screen | sed -n '1p;3p')" "The Claude Code session \"earlier\" (pid ${pid[earlier]}, a CLI session on $terminal_name, stopped) works in this working tree, $main, which has the branch main checked out, and started before this session.
\"earlier\" is stopped, a job of the shell that started it on this terminal, so a plain kill leaves it stopped: end this session with /exit, then run fg in that shell and end \"earlier\" with /exit."

next_case
start_session earlier "$main" cli idle pty
start_session later "$main" cli busy
stop_session earlier
run_hook later SessionStart
check "session start beside a stopped job of a shell on another terminal: fg there" \
  equals "$(on_screen | sed -n 3p)" "\"earlier\" is stopped, a job of the shell that started it on $terminal_name, so a plain kill leaves it stopped: run fg in that shell and end it with /exit."

next_case
start_session killed "$main" cli busy
start_session later "$main" cli busy
run_hook later PreToolUse Bash
before=$(verdict)
kill_session killed
run_hook later PreToolUse Bash
check "an earlier session killed, its entry left in the registry: refused before the kill, allowed after it" \
  equals "$before|$code|$out|$err|$(find "$registry" -name '*.json' | wc -l)" "refused|0|||2"

next_case
start_session reused "$main" cli busy
start_session later "$main" cli busy
run_hook later PreToolUse Bash
before=$(verdict)
register reused cli busy "$(($(process_start_in_clock_ticks_after_boot "${pid[reused]}") - 1))"
run_hook later PreToolUse Bash
check "an entry whose pid runs with another start time: counts until the start time differs" \
  equals "$before|$code|$out|$err" "refused|0||"

next_case
start_session earlier "$main" cli idle
start_session later "$main" cli busy
echo '{"pid": "not a number"' >"$registry/1.json"
run_hook later PreToolUse Bash
before=$(verdict)
run_hook earlier SessionStart
check "its own entry there, beside an unreadable one: refused, and nothing said at the earlier one's session start" \
  equals "$before|$code|$out|$err" "refused|0||"
rm "$registry/${pid[later]}.json"
run_hook later PreToolUse Bash
check "its own entry missing: allowed, and nothing said before a call" equals "$code|$out|$err" "0||"
run_hook later SessionStart
check "its own entry missing: one line at session start names the registry" \
  equals "$code|$out|$err" "0|Claude Code's registry of live sessions, $registry, holds no entry for this session, so the repo plugin cannot tell whether another session works in this working tree, and nothing stops a second session from working in it beside this one.|"

if ((failures > 0)); then
  echo "session check tests: $failures failure(s)" >&2
  exit 1
fi
echo "session check tests: ok"
