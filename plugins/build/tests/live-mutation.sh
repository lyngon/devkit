#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

if (($# != 1)); then
  echo "usage: live-mutation.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
devkit=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
script=$devkit/plugins/build/skills/live-mutation/scripts/live-mutation.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

derive='read -r v <desired && printf "%s\n" "$v" >"$LIVE_MUTATION_INPUTS/plan"'
show='read -r l <live && read -r p <"$LIVE_MUTATION_INPUTS/plan" && printf "value: %s -> %s\n" "$l" "$p"'
apply='read -r p <"$LIVE_MUTATION_INPUTS/plan" && printf "%s\n" "$p" >live && printf "applied %s\n" "$p"'
matches='read -r l <live && read -r d <desired && test "$l" = "$d"'
present='test -f live'

mutation() {
  local session=$1
  shift
  status=0
  output=$(cd "$repository" && env -i PATH="$script_tools" CLAUDE_CODE_SESSION_ID="$session" "$script" "$@" 2>&1) || status=$?
}

new_repository() {
  repository=$(mktemp -d "$tmp/repository.XXXXXX")
  mkdir "$repository/.git"
  printf '%s\n' "$1" >"$repository/live"
  printf '%s\n' "$2" >"$repository/desired"
}

propose_value_change() {
  mutation session-one propose set-value --derive "$derive" --show "$show" --run "$apply" \
    --check "matches=$matches" --check "present=$present"
  digest=$(sed -n 's/^Proposal `set-value` at digest `\([0-9a-f]*\)`.*/\1/p' <<<"$output")
}

live_value() {
  cat "$repository/live"
}

pass() {
  echo "ok: $1"
}

fail() {
  echo "FAIL: $1: $2"
  failures=$((failures + 1))
}

expect() {
  local label=$1 wanted_status=$2 pattern=$3
  if ((status == wanted_status)) && [[ "$output" =~ $pattern ]]; then
    pass "$label"
  else
    fail "$label" "expected exit $wanted_status and /$pattern/, got exit $status and:"$'\n'"$output"
  fi
}

expect_live() {
  local label=$1 wanted=$2 found
  found=$(live_value)
  if [[ "$found" == "$wanted" ]]; then
    pass "$label"
  else
    fail "$label" "live holds '$found', expected '$wanted'"
  fi
}

new_repository old new
status=0
output=$(cd "$repository" && env -i PATH="$script_tools" "$script" propose set-value --derive "$derive" --show "$show" --run "$apply" 2>&1) || status=$?
expect "a proposal outside a Claude Code session is refused" 1 '^live-mutation\.py: no-conversation: '

propose_value_change
expect "a proposal shows its digest, its command, its rendering and how each check did" 0 \
  'Proposal `set-value` at digest `[0-9a-f]{16}`, shown in session `session-one`\..*'"read -r p <\"\\\$LIVE_MUTATION_INPUTS/plan\".*value: old -> new.*- \`matches\` fails \(1\).*- \`present\` passes"
expect_live "a proposal changes nothing live" old
if [[ -f "$repository/tmp/live-mutation/session-one/set-value/inputs/plan" ]]; then
  pass "a proposal keeps its inputs under the directory of its session"
else
  fail "a proposal keeps its inputs under the directory of its session" "no tmp/live-mutation/session-one/set-value/inputs/plan"
fi

new_repository old new
mutation session-one propose set-value --derive 'exit 3' --show "$show" --run "$apply"
expect "a derive command that fails is no proposal" 1 '^live-mutation\.py: derive-failed: derive exited 3'

mutation session-one propose Set_Value --derive "$derive" --show "$show" --run "$apply"
expect "a name that is no kebab-case name is refused" 1 "^live-mutation\.py: bad-name: 'Set_Value'"

new_repository old new
propose_value_change
mutation session-one run set-value 0000000000000000 --go-ahead "yes"
expect "a go-ahead for another digest is refused" 1 "^live-mutation\.py: digest-mismatch: the go-ahead names 0000000000000000, and proposal set-value is at $digest"
expect_live "a refused digest changes nothing live" old

mutation session-two run set-value "$digest" --go-ahead "yes, the one from yesterday"
expect "a proposal shown in another conversation is refused, naming that session" 1 \
  '^live-mutation\.py: not-in-this-conversation: this conversation \(session session-two\) showed no proposal set-value\. It was shown in session session-one\.'
expect_live "a proposal of another conversation changes nothing live" old

printf 'tampered\n' >"$repository/tmp/live-mutation/session-one/set-value/inputs/plan"
mutation session-one run set-value "$digest" --go-ahead "yes"
expect "an input that changed after the proposal is refused" 1 '^live-mutation\.py: inputs-changed: plan changed since the proposal'
expect_live "changed inputs change nothing live" old

new_repository old new
propose_value_change
printf 'drifted\n' >"$repository/live"
mutation session-one run set-value "$digest" --go-ahead "yes"
expect "a live system that drifted since the proposal is refused with the diff" 1 \
  '^live-mutation\.py: drifted: live state no longer gives the rendering the owner approved.*-value: old -> new.*\+value: drifted -> new'
expect_live "a drifted proposal changes nothing live" drifted

new_repository old new
propose_value_change
mutation session-one record set-value
expect "a proposal that never ran has no record" 1 '^live-mutation\.py: not-run: '

mutation session-one run set-value "$digest" --go-ahead "Go ahead with set-value."
expect "a go-ahead for the digest runs the proposal and checks it again" 0 \
  'The run passes.*applied new.*- `matches` passes.*- `present` passes'
expect_live "the run changes the live system" new

mutation session-one run set-value "$digest" --go-ahead "Go ahead with set-value."
expect "a second run on the same go-ahead is refused" 1 \
  "^live-mutation\.py: already-ran: proposal set-value ran on the go-ahead 'Go ahead with set-value\.'"

mutation session-one record set-value
expect "a record with a check that never failed is refused" 1 \
  '^live-mutation\.py: check-never-failed: the check present never failed'

mutation session-one demonstrate set-value present 'test -f absent'
expect "a demonstration where the property does not hold is logged as a failure" 0 'The demonstration of present fails \(1\)'

mutation session-one demonstrate set-value present 'test -f live'
expect "a demonstration that passes is reported as showing nothing" 1 'The demonstration of present passed, so it shows nothing'

mutation session-one record set-value
expect "the record is written once every check has failed somewhere" 0 'tmp/live-mutation/session-one/set-value/record-1\.md'
record=$(cat "$repository/tmp/live-mutation/session-one/set-value/record-1.md")
pattern='^## Action record of `set-value`.*Proposal digest `'"$digest"'`.*Go-ahead at [0-9TZ:-]+, in the owner.s words: "Go ahead with set-value\.".*Drift check at [0-9TZ:-]+: the rendering derived again equals the approved one.*The run passes.*\| `matches` \| fails \(1\) \| passes \| none \|.*\| `present` \| passes \| passes \| fails \(1\), passes \|.*value: old -> new.*applied new'
if [[ "$record" =~ $pattern ]]; then
  pass "the record holds the digest, the owner's words, the run, every check and the rendering"
else
  fail "the record holds the digest, the owner's words, the run, every check and the rendering" "got:"$'\n'"$record"
fi

mutation session-two record set-value --session session-one
expect "another session may write the record of a run, naming the session" 0 'tmp/live-mutation/session-one/set-value/record-1\.md'

mutation session-one propose set-value --derive "$derive" --show "$show" --run "$apply"
expect "a name that already ran cannot be proposed again" 1 '^live-mutation\.py: already-ran: proposal set-value ran at '

new_repository old new
cat >"$repository/count-interrupts.py" <<'EOF'
import pathlib, signal, sys, time
seen = []
signal.signal(signal.SIGINT, lambda *_: seen.append(1))
end = time.monotonic() + 3
while time.monotonic() < end:
    time.sleep(0.05)
pathlib.Path(sys.argv[1]).write_text(f"{len(seen)}\n")
EOF
mutation session-one propose interruptible --derive 'printf x >"$LIVE_MUTATION_INPUTS/plan"' --show 'printf "count interrupts\n"' \
  --run 'python3 count-interrupts.py interrupts'
digest=$(sed -n 's/^Proposal `interruptible` at digest `\([0-9a-f]*\)`.*/\1/p' <<<"$output")
status=0
output=$(cd "$repository" && env -i PATH="$script_tools" CLAUDE_CODE_SESSION_ID=session-one python3 -c '
import os, signal, subprocess, sys, time
run = subprocess.Popen(sys.argv[1:], start_new_session=True)
time.sleep(1)
os.killpg(run.pid, signal.SIGINT)
sys.exit(run.wait())' "$script" run interruptible "$digest" --go-ahead "yes" 2>&1) || status=$?
interrupts=$(cat "$repository/interrupts" 2>/dev/null || echo none)
if ((status == 0)) && [[ "$interrupts" == 1 ]]; then
  pass "a Ctrl-C reaches the running command once, and the run is waited for"
else
  fail "a Ctrl-C reaches the running command once, and the run is waited for" "exit $status, the command saw $interrupts interrupts:"$'\n'"$output"
fi

if ((failures > 0)); then
  echo "test-live-mutation: $failures failure(s)" >&2
  exit 1
fi
