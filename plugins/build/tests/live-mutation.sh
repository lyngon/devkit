#!/usr/bin/env bash
# shellcheck disable=SC2016  # the commands and patterns hold a literal $ for the tool's sh and for regexes
set -euo pipefail

if (($# != 2)); then
  echo "usage: live-mutation.sh <the PATH that holds the script tools> <the PATH that holds tofu>" >&2
  exit 2
fi
script_tools=$1
opentofu=$2
devkit=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
script=$devkit/plugins/build/skills/live-mutation/scripts/live-mutation.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="Ada Lovelace" GIT_AUTHOR_EMAIL=ada@example.com
export GIT_COMMITTER_NAME="Ada Lovelace" GIT_COMMITTER_EMAIL=ada@example.com

derive='read -r v <desired && printf "%s planned-by-%s\n" "$v" "$$" >"$LIVE_MUTATION_INPUTS/plan"'
show='read -r l <live && read -r p _ <"$LIVE_MUTATION_INPUTS/plan" && printf "value: %s -> %s\n" "$l" "$p"'
apply='read -r p _ <"$LIVE_MUTATION_INPUTS/plan" && printf "%s\n" "$p" >live && printf "applied %s\n" "$p"'
matches='read -r l <live && read -r d <desired && test "$l" = "$d"'
present='test -f live'

environment=()

call_tool() {
  local path=$1 session=$2
  shift 2
  status=0
  output=$(cd "$repository" && env -i PATH="$path" CLAUDE_CODE_SESSION_ID="$session" "${environment[@]}" "$script" "$@" 2>&1) || status=$?
}

mutation() {
  call_tool "$script_tools" "$@"
}

tofu_mutation() {
  call_tool "$script_tools:$opentofu" "$@"
}

new_repository() {
  repository=$(mktemp -d "$tmp/repository.XXXXXX")
  git init -q -b main "$repository"
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

contents() {
  if [[ -f "$1" ]]; then cat "$1"; else echo "no file $1"; fi
}

line_count() {
  if [[ -f "$1" ]]; then wc -l <"$1"; else echo "no file $1"; fi
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
  'Proposal `set-value` at digest `[0-9a-f]{16}`, shown in session `session-one`\..*'"read -r p _ <\"\\\$LIVE_MUTATION_INPUTS/plan\".*value: old -> new.*- \`matches\` fails \(1\).*- \`present\` passes"
expect_live "a proposal changes nothing live" old
if [[ -f "$repository/tmp/live-mutation/session-one/set-value/inputs/plan" ]]; then
  pass "a proposal keeps its inputs under the directory of its session"
else
  fail "a proposal keeps its inputs under the directory of its session" "no tmp/live-mutation/session-one/set-value/inputs/plan"
fi

new_repository old new
mutation session-one propose set-value --derive "$derive" --show "$show" --run "$apply" \
  --check 'rewrites=printf "other\n" >"$LIVE_MUTATION_INPUTS/plan"; false'
expect "a check that rewrites an input while the proposal is made is refused" 1 \
  '^live-mutation\.py: inputs-changed: plan changed while the checks ran'
if [[ ! -e "$repository/tmp/live-mutation/session-one/set-value/proposal.json" ]]; then
  pass "a check that rewrites an input leaves no proposal"
else
  fail "a check that rewrites an input leaves no proposal" "it saved proposal.json"
fi

new_repository old new
mutation session-one propose set-value --derive 'exit 3' --show "$show" --run "$apply"
expect "a derive command that fails is no proposal" 1 '^live-mutation\.py: derive-failed: derive exited 3'

mutation session-one propose Set_Value --derive "$derive" --show "$show" --run "$apply"
expect "a name that is no kebab-case name is refused" 1 "^live-mutation\.py: bad-name: 'Set_Value'"

new_repository old new
treeless=$(printf 'tree %s\nauthor A <a@example.com> 0 +0000\ncommitter A <a@example.com> 0 +0000\n\nno tree\n' \
  0123456789abcdef0123456789abcdef01234567 | git -C "$repository" hash-object -t commit -w --stdin)
git -C "$repository" update-ref refs/remotes/origin/HEAD "$treeless"
propose_value_change
expect "a proposal of the generic form reads no rule file, so a default branch that git cannot read leaves it alone" 0 \
  'Proposal `set-value` at digest `[0-9a-f]{16}`.*The run waits for the owner.s go-ahead:'$'\n\n''- The proposal is of the generic form, and only the OpenTofu form runs without a go-ahead\.'$'\n'
mutation session-one run set-value "$digest"
expect "a run of the generic form without a go-ahead is refused without reading a rule file" 1 \
  '^live-mutation\.py: needs-go-ahead: proposal set-value runs only on the owner.s go-ahead:'$'\n''- The proposal is of the generic form, and only the OpenTofu form runs without a go-ahead\.'$'\n'
expect_live "a refused run of the generic form changes nothing live" old

new_repository old new
propose_value_change
mutation session-one run set-value 0000000000000000 --go-ahead "yes"
expect "a go-ahead for another digest is refused" 1 "^live-mutation\.py: digest-mismatch: the run names 0000000000000000, and proposal set-value is at $digest"
expect_live "a refused digest changes nothing live" old

mutation session-one run set-value "$digest" --go-ahead " "
expect "a go-ahead without words is refused" 1 '^live-mutation\.py: empty-go-ahead: '
expect_live "a go-ahead without words changes nothing live" old

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
mutation session-one posted set-value https://github.com/acme/orders/pull/7#issuecomment-1
expect "a proposal that never ran has no record to post" 1 '^live-mutation\.py: not-run: proposal set-value has not run'

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
record=$(contents "$repository/tmp/live-mutation/session-one/set-value/record-1.md")
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
propose_value_change
mutation session-one run set-value "$digest" --go-ahead "Go ahead with set-value."
mutation session-two record set-value --session session-one
expect "a record of another session with a check that never failed is refused, with a demonstration that names the session" 1 \
  "^live-mutation\.py: check-never-failed: the check present never failed, so it is no evidence; run [^ ]*/live-mutation\.py demonstrate set-value present '<cmd>' --session session-one where its property does not hold"
mutation session-two demonstrate set-value present 'test -f absent'
expect "a demonstration of a proposal of another session that names no session is refused" 1 \
  '^live-mutation\.py: not-found: session session-two holds no proposal set-value'
mutation session-two demonstrate set-value present 'test -f absent' --session 'a b'
expect "demonstrate refuses a session that is no session ID" 1 "^live-mutation\.py: bad-session: 'a b' is no session ID"
mutation session-two demonstrate set-value present 'test -f absent' --session session-one
expect "another session may demonstrate a check of a run, naming the session" 0 'The demonstration of present fails \(1\)'
mutation session-two record set-value --session session-one
expect "another session writes the record once it demonstrated the check" 0 'tmp/live-mutation/session-one/set-value/record-1\.md'
record=$(contents "$repository/tmp/live-mutation/session-one/set-value/record-1.md")
pattern='\| `present` \| passes \| passes \| fails \(1\) \|.*demonstration present, after the run: fails \(1\)'
if [[ "$record" =~ $pattern ]]; then
  pass "the record shows the demonstration of another session, after the run"
else
  fail "the record shows the demonstration of another session, after the run" "got:"$'\n'"$record"
fi

new_repository new new
mkdir -p "$repository/tmp/live-mutation"
cp -R "$devkit/plugins/build/tests/live-mutation/released-session" "$repository/tmp/live-mutation/"
mutation session-two pending
expect "pending reads a run of the released tool, which kept no branch, and lists it for no branch" 0 \
  '^No run of branch `main` waits for its action record to be posted\.$'
mutation session-two record set-value --session released-session
expect "record writes the record of a run of the released tool" 0 'tmp/live-mutation/released-session/set-value/record-1\.md'
record=$(contents "$repository/tmp/live-mutation/released-session/set-value/record-1.md")
pattern='^## Action record of `set-value`.*Proposal digest `d82461173b295852`.*- Go-ahead at 2026-11-18T04:36:17Z, in the owner.s words: "Go ahead with set-value\.".*\| `matches` \| fails \(1\) \| passes \| none \|'
if [[ "$record" =~ $pattern ]]; then
  pass "the record of a run of the released tool holds its digest, the owner's words and its check"
else
  fail "the record of a run of the released tool holds its digest, the owner's words and its check" "got:"$'\n'"$record"
fi
mutation released-session run set-value d82461173b295852 --go-ahead "Go ahead with set-value."
expect "a run of the released tool reads as used up" 1 \
  "^live-mutation\.py: already-ran: proposal set-value ran on the go-ahead 'Go ahead with set-value\.'"

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
interrupts=$(contents "$repository/interrupts")
logged='The run (passes|ended by signal 2); its whole output is in '
if [[ "$interrupts" == 1 && "$output" =~ $logged ]]; then
  pass "a Ctrl-C reaches the running command once, and the run is waited for"
else
  fail "a Ctrl-C reaches the running command once, and the run is waited for" "exit $status, the command saw $interrupts interrupts:"$'\n'"$output"
fi

new_repository old new
mkdir -p "$repository/infra/staging"
mutation session-one propose by-hand --opentofu infra/staging --derive "$derive"
expect "the OpenTofu form takes no command of the generic form" 2 'it takes none of them'
mutation session-one propose by-hand --derive "$derive" --show "$show"
expect "the generic form takes all three commands" 2 'propose takes --derive, --show and --run, or --opentofu'
mutation session-one propose by-hand --derive "$derive" --show "$show" --run "$apply" --destroy
expect "a destroy takes the OpenTofu form" 2 '--destroy plans a destroy of the OpenTofu form'
mutation session-one propose by-hand --opentofu infra/staging --check 'no-changes=true'
expect "the OpenTofu form refuses a check of its own named no-changes" 1 '^live-mutation\.py: reserved-check: '
for root in "$repository/infra/staging" infra/../infra/staging infra/missing; do
  mutation session-one propose by-hand --opentofu "$root"
  expect "a root module at $root is refused" 1 '^live-mutation\.py: bad-root: '
done
ln -s staging "$repository/infra/link"
mkdir -p "$repository/infra/staging/nested"
for root in infra/link infra/link/nested; do
  mutation session-one propose by-hand --opentofu "$root"
  expect "a root module at $root, through a symlink to a directory, is refused" 1 \
    '^live-mutation\.py: bad-root: infra/link is a symlink; name the directory it points to$'
done

token=s3cr3t-token-of-the-test
proposals=tmp/live-mutation/session-one

new_tofu_repository() {
  repository=$(mktemp -d "$tmp/repository.XXXXXX")
  git init -q -b main "$repository"
  printf '%s\n' /tmp/ .terraform/ 'terraform.tfstate*' >"$repository/.gitignore"
  module infra/staging
}

module() {
  mkdir -p "$repository/$1"
  cat >"$repository/$1/main.tf" <<EOF
variable "level" {
  type    = string
  default = "info"
}

variable "token" {
  type      = string
  sensitive = true
  default   = "$token"
}

resource "terraform_data" "logging" {
  input            = var.level
  triggers_replace = "first"
}

resource "terraform_data" "credentials" {
  input = var.token
}

resource "terraform_data" "spare" { input = "spare" }

output "level" {
  value = terraform_data.logging.output
}
EOF
}

rule() {
  local file=$1
  shift
  mkdir -p "$repository/.claude/rules"
  printf '%s\n' --- "$@" --- "" "# A rule of the test" >"$repository/.claude/rules/$file"
}

tofu_in() {
  local root=$1
  shift
  (cd "$repository" && env -i PATH="$opentofu" tofu -chdir="$root" "$@")
}

publish() {
  local root
  git -C "$repository" add -A
  git -C "$repository" commit -q -m "feat(infra): describe staging"
  origin=$(mktemp -d "$tmp/origin.XXXXXX")
  git init -q --bare -b main "$origin"
  git -C "$repository" remote add origin "$origin"
  git -C "$repository" push -q origin main
  git -C "$repository" remote set-head origin main
  git -C "$repository" switch -q -c feat/staging-logs
  for root in "$repository"/infra/*/; do
    root=${root#"$repository/"}
    tofu_in "$root" init -input=false >/dev/null
    tofu_in "$root" apply -input=false -auto-approve >/dev/null
  done
}

set_level() {
  sed -i 's/default = "info"/default = "debug"/' "$repository/$1/main.tf"
}

state_of() {
  local file=$repository/$1/terraform.tfstate
  if [[ -f "$file" ]]; then sha256sum "$file"; else echo "no state"; fi
}

propose_tofu() {
  tofu_mutation session-one propose "$@"
  digest=$(sed -n 's/^Proposal `[a-z0-9-]*` at digest `\([0-9a-f]*\)`.*/\1/p' <<<"$output")
}

edit_proposal() {
  env -i PATH="$script_tools" python3 -c '
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
proposal = json.loads(path.read_text())
exec(sys.argv[2])
path.write_text(json.dumps(proposal))' "$repository/$proposals/$1/proposal.json" "$2"
}

rest_of_line="[^"$'\n'"]*"

expect_waits() {
  local label=$1 name=$2 root=$3 reasons="" reason state lines state_after lines_after
  local log=$repository/$proposals/$name/log.jsonl
  shift 3
  for reason in "$@"; do
    reasons+="- $reason"$'\n'
  done
  state=$(state_of "$root")
  lines=$(line_count "$log")
  tofu_mutation session-one run "$name" "$digest"
  expect "$label: a run without a go-ahead is refused, with exactly these reasons" 1 \
    "^live-mutation\.py: needs-go-ahead: proposal $name runs only on the owner's go-ahead:"$'\n'"${reasons}Show the owner the proposal and ask\."
  state_after=$(state_of "$root")
  lines_after=$(line_count "$log")
  if [[ "$state_after" == "$state" && "$lines_after" == "$lines" ]]; then
    pass "$label: the refused run changes no state and adds no line to the log"
  else
    fail "$label: the refused run changes no state and adds no line to the log" "the state or the log changed"
  fi
  tofu_mutation session-one run "$name" "$digest" --go-ahead "Go ahead with $name."
  expect "$label: a run on a go-ahead applies the plan" 0 'The run passes.*- `no-changes` passes'
  state_after=$(state_of "$root")
  if [[ "$state_after" != "$state" ]]; then
    pass "$label: the run on a go-ahead changes the state"
  else
    fail "$label: the run on a go-ahead changes the state" "the state is unchanged"
  fi
}

new_tofu_repository
module infra/staging-old
rule sandbox.md "unprotected-roots:" "  - infra/staging"
rule plain.md "paths:" '  - "**/*.tf"'
publish
declared=$(git -C "$repository" rev-parse refs/remotes/origin/HEAD)
set_level infra/staging
propose_tofu staging-logs --opentofu ./infra/staging/
expect "an update-only plan of a root module declared on origin/HEAD needs no go-ahead" 0 \
  'tofu -chdir=infra/staging apply -no-color -input=false "\$LIVE_MUTATION_INPUTS/plan".*- `no-changes` fails \(2\): `tofu -chdir=infra/staging plan -no-color -input=false -detailed-exitcode`.*The run needs no go-ahead: `\.claude/rules/sandbox\.md` at `'"$declared"'` lists `infra/staging` under `unprotected-roots:`, and the plan deletes and replaces nothing\.'$'\n''Run it without one only when you judge that the apply can be undone and that the plan reaches only the target that the rule names:.*run staging-logs '"$digest"$'\n''```.*run staging-logs '"$digest"" --go-ahead '<the owner's words>'"
tofu_mutation session-one run staging-logs "$digest"
expect "a run without a go-ahead applies the plan and checks it again" 0 'The run passes.*- `no-changes` passes'
level=$(tofu_in infra/staging output -raw level || true)
if [[ "$level" == debug ]]; then
  pass "the run without a go-ahead changes the state"
else
  fail "the run without a go-ahead changes the state" "level is '$level'"
fi
tofu_mutation session-one run staging-logs "$digest"
expect "a second run without a go-ahead is refused" 1 '^live-mutation\.py: already-ran: proposal staging-logs ran without a go-ahead at '
tofu_mutation session-one record staging-logs
expect "the record of a run without a go-ahead is written" 0 'session-one/staging-logs/record-1\.md'
record=$(contents "$repository/$proposals/staging-logs/record-1.md")
pattern='^## Action record of `staging-logs`.*- No go-ahead was asked: `\.claude/rules/sandbox\.md` at `'"$declared"'` lists `infra/staging` under `unprotected-roots:`, and the plan deletes and replaces nothing\.'$'\n''- Drift check at [0-9TZ:-]+: the rendering derived again equals the proposed one\..*\| `no-changes` \| fails \(2\) \| passes \| none \|.*<summary>The rendering of the proposal</summary>'
if [[ "$record" =~ $pattern && "$record" != *owner* ]]; then
  pass "the record names the rule file, says that no go-ahead was asked, and names no owner"
else
  fail "the record names the rule file, says that no go-ahead was asked, and names no owner" "got:"$'\n'"$record"
fi
plan_json=$(tofu_in infra/staging show -json "$repository/$proposals/staging-logs/inputs/plan" || true)
searched=0
holders=$(grep -rl --binary-files=text "$token" "$repository/tmp/live-mutation") || searched=$?
unexpected=$(sed '\#/staging-logs/\(drift/\)\{0,1\}inputs/plan$#d' <<<"$holders")
if ((searched <= 1)) && [[ "$plan_json" == *"$token"* && -z "$unexpected" ]]; then
  pass "the plan's JSON holds the sensitive value, and no file of the proposal, its record included, does but its saved plans"
else
  fail "the plan's JSON holds the sensitive value, and no file of the proposal, its record included, does but its saved plans" \
    "grep exited $searched and found it in:"$'\n'"$unexpected"
fi
escaped=0
escapes=$(grep -rl --binary-files=text --exclude-dir=inputs $'\e' "$repository/$proposals/staging-logs") || escaped=$?
if ((escaped == 1)) && [[ "$record" == *"Apply complete!"* ]]; then
  pass "the record holds the output of the apply, and no output of the proposal holds an ANSI escape"
else
  fail "the record holds the output of the apply, and no output of the proposal holds an ANSI escape" \
    "grep exited $escaped and found one in:"$'\n'"$escapes"
fi

sleep 1
set_level infra/staging-old
propose_tofu old-logs --opentofu infra/staging-old
expect_waits "a root module beside a declared directory with the same prefix" old-logs infra/staging-old \
  'No rule file under `\.claude/rules/` at `'"$declared"'` lists `infra/staging-old` or a directory above it under `unprotected-roots:`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

mutation session-two pending
expect "pending lists the unposted runs of the branch from every session, in the order they ran" 0 \
  '^The runs of branch `feat/staging-logs` whose action record is not posted, in the order they ran:.*- `staging-logs` of session `session-one`, run without a go-ahead at [0-9TZ:-]+\..*record staging-logs --session session-one'$'\n'' *[^ ]* posted staging-logs <url>\.\.\. --session session-one.*- `old-logs` of session `session-one`, run on a go-ahead at '
mutation session-one posted staging-logs https://github.com/acme/orders/pull/7#issuecomment-1 --session 'a b'
expect "posted refuses a session that is no session ID" 1 "^live-mutation\.py: bad-session: 'a b' is no session ID"
mutation session-one record staging-logs --session 'a b'
expect "record refuses a session that is no session ID" 1 "^live-mutation\.py: bad-session: 'a b' is no session ID"
mutation session-two pending
expect "a posted that names no session ID leaves the run of this session pending" 0 \
  '- `staging-logs` of session `session-one`, run without a go-ahead at '
git -C "$repository" switch -q -c feat/other
mutation session-two pending
expect "pending lists no run of another branch" 0 '^No run of branch `feat/other` waits for its action record to be posted\.$'
git -C "$repository" switch -q feat/staging-logs
mutation session-two posted staging-logs https://github.com/acme/orders/pull/7#issuecomment-1 --session session-one
expect "posted logs the URL of a run's record, naming its session" 0 \
  '^The action record of staging-logs is posted at https://github\.com/acme/orders/pull/7#issuecomment-1\.$'
mutation session-two posted old-logs comment-2 --session session-one
expect "posted refuses what is no https URL" 1 '^live-mutation\.py: bad-url: comment-2 is no https URL'
mutation session-two posted old-logs https://github.com/acme/orders/pull/7#issuecomment-2 --session session-one
mutation session-two pending
expect "pending lists nothing once every record of the branch is posted" 0 \
  '^No run of branch `feat/staging-logs` waits for its action record to be posted\.$'
mkdir -p "$repository/tmp/live-mutation/session-old/stale"
printf '{}\n' >"$repository/tmp/live-mutation/session-old/stale/proposal.json"
mutation session-two pending
expect "pending names a proposal it cannot read, and fails" 1 \
  'could not be read.*- tmp/live-mutation/session-old/stale/proposal\.json: corrupt: '

new_tofu_repository
publish
rule sandbox.md "unprotected-roots:" "  - infra/staging"
git -C "$repository" add -A
git -C "$repository" commit -q -m "docs(rules): call staging unprotected"
git -C "$repository" push -q -u origin feat/staging-logs
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "a declaration committed and pushed on the agent's branch only" staging-logs infra/staging \
  'No rule file under `\.claude/rules/` at `[0-9a-f]{40}` lists `infra/staging` or a directory above it under `unprotected-roots:`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra"
publish
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect "a directory above the root module, declared on origin/HEAD, lets an update-only plan need no go-ahead" 0 \
  'The run needs no go-ahead: `\.claude/rules/sandbox\.md` at `[0-9a-f]{40}` lists `infra` under `unprotected-roots:`, and the plan deletes and replaces nothing\.'
tofu_mutation session-one run staging-logs "$digest"
expect "a run under a declared directory above the root module applies without a go-ahead" 0 'The run passes.*- `no-changes` passes'
git -C "$repository" checkout -q -- infra/staging/main.tf
sed -i 's/"first"/"second"/' "$repository/infra/staging/main.tf"
propose_tofu staging-replace --opentofu infra/staging
expect_waits "a plan that replaces" staging-replace infra/staging \
  'The plan does more than create, read or update these resources: `terraform_data\.logging`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
sed -i '/"spare"/d' "$repository/infra/staging/main.tf"
propose_tofu staging-delete --opentofu infra/staging
expect_waits "a plan that deletes" staging-delete infra/staging \
  'The plan does more than create, read or update these resources: `terraform_data\.spare`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
sed -i '/"spare"/d' "$repository/infra/staging/main.tf"
printf '%s\n' 'removed {' '  from = terraform_data.spare' '  lifecycle {' '    destroy = false' '  }' '}' >>"$repository/infra/staging/main.tf"
propose_tofu staging-forget --opentofu infra/staging
expect_waits "a plan that forgets, which deletes nothing" staging-forget infra/staging \
  'The plan does more than create, read or update these resources: `terraform_data\.spare`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
printf '%s\n' 'import {' '  to = terraform_data.adopted' '  id = "an-object-of-another-root-module"' '}' \
  'resource "terraform_data" "adopted" {' '  input = "changed-by-staging"' '}' >"$repository/infra/staging/adopted.tf"
propose_tofu staging-adopt --opentofu infra/staging
expect_waits "a plan that imports and updates" staging-adopt infra/staging \
  'The plan imports these resources, and so adopts objects that the state of `infra/staging` never held: `terraform_data\.adopted`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
sed -i '/^resource "terraform_data" "credentials" {$/,/^}$/d' "$repository/infra/staging/main.tf"
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
propose_tofu staging-destroy --opentofu infra/staging --destroy
expect "a destroy of resources that hold no sensitive value plans and checks with -destroy" 0 \
  'terraform_data\.logging will be destroyed.*- `no-changes` fails \(2\): `tofu -chdir=infra/staging plan -no-color -input=false -destroy -detailed-exitcode`'
expect_waits "a destroy plan" staging-destroy infra/staging \
  'The plan does more than create, read or update these resources: `terraform_data\.logging`, `terraform_data\.spare`\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
propose_tofu staging-by-hand \
  --derive 'tofu -chdir=infra/staging plan -input=false -out="$LIVE_MUTATION_INPUTS/plan"' \
  --show 'tofu -chdir=infra/staging show -no-color "$LIVE_MUTATION_INPUTS/plan"' \
  --run 'tofu -chdir=infra/staging apply -input=false "$LIVE_MUTATION_INPUTS/plan"' \
  --check 'no-changes=tofu -chdir=infra/staging plan -input=false -detailed-exitcode'
expect_waits "a proposal of the generic form" staging-by-hand infra/staging \
  'The proposal is of the generic form, and only the OpenTofu form runs without a go-ahead\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect "a proposal made while origin/HEAD declared its root module needs no go-ahead" 0 'The run needs no go-ahead: '
state=$(state_of infra/staging)
tofu_mutation session-one run staging-logs 0000000000000000
expect "a run without a go-ahead for another digest is refused" 1 \
  "^live-mutation\.py: digest-mismatch: the run names 0000000000000000, and proposal staging-logs is at $digest"
plan=$repository/$proposals/staging-logs/inputs/plan
cp "$plan" "$tmp/plan"
printf 'tampered\n' >"$plan"
tofu_mutation session-one run staging-logs "$digest"
expect "a run without a go-ahead of inputs that changed is refused" 1 '^live-mutation\.py: inputs-changed: plan changed since the proposal'
cp "$tmp/plan" "$plan"
sed -i 's/default = "debug"/default = "trace"/' "$repository/infra/staging/main.tf"
tofu_mutation session-one run staging-logs "$digest"
expect "a run without a go-ahead of a root module that drifted is refused with the diff" 1 \
  '^live-mutation\.py: drifted: live state no longer gives the rendering of the proposal.*\+.*"trace"'
sed -i 's/default = "trace"/default = "debug"/' "$repository/infra/staging/main.tf"
if [[ "$(state_of infra/staging)" == "$state" ]]; then
  pass "a run without a go-ahead refused for its digest, its inputs or drift changes no state"
else
  fail "a run without a go-ahead refused for its digest, its inputs or drift changes no state" "the state changed"
fi
git -C "$repository" remote set-head origin --delete
expect_waits "a missing origin/HEAD at the run" staging-logs infra/staging \
  '`refs/remotes/origin/HEAD` is missing, while origin.s default branch is `main` at `'"$(git -C "$origin" rev-parse main)"'`\. Run `git fetch origin` and `git remote set-head origin --auto`, and propose again\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
rule plain.md "paths:" '  - "**/*.tf"'
rule broken-scalar.md "unprotected-roots: infra/staging"
rule broken-flow.md "unprotected-roots: [infra/staging]"
rule broken-glob.md "unprotected-roots:" "  - infra/*"
rule broken-climbs.md "unprotected-roots:" "  - infra/../infra/staging"
rule broken-absolute.md "unprotected-roots:" "  - /infra/staging"
rule broken-empty.md "unprotected-roots:" "paths:" '  - "**/*.tf"'
rule broken-nested.md "unprotected-roots:" "  - path: infra/staging"
rule broken-indent.md "unprotected-roots:" "  - infra/staging" "    - infra/production"
rule broken-comment.md "unprotected-roots:" "  - infra/staging" "# - infra/production" "  - infra/sandbox"
rule broken-indented-comment.md "unprotected-roots:" "  - infra/staging" "  # - infra/production" "  - infra/sandbox"
publish
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
broken=()
for file in absolute climbs comment empty flow glob indent indented-comment nested scalar; do
  broken+=('`\.claude/rules/broken-'"$file"'\.md` at `[0-9a-f]{40}` names `unprotected-roots:` in a form the tool does not read, since '"$rest_of_line")
  expect "frontmatter of broken-$file.md that is no list of plain directories makes the proposal wait" 0 \
    'The run waits for the owner.s go-ahead:.*- `\.claude/rules/broken-'"$file"'\.md` at `[0-9a-f]{40}` names `unprotected-roots:` in a form the tool does not read'
done
if [[ "$output" != *plain.md* ]]; then
  pass "a rule file without unprotected-roots counts for nothing"
else
  fail "a rule file without unprotected-roots counts for nothing" "the proposal names it:"$'\n'"$output"
fi
expect_waits "frontmatter that is no list of directories" staging-logs infra/staging "${broken[@]}" \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
emptied=$tmp/emptied-actions
mkdir -p "$emptied"
cat >"$emptied/tofu" <<EOF
#!/bin/sh
case " \$* " in
*" show -json "*)
  "$opentofu/tofu" "\$@" | python3 -c 'import json, sys; plan = json.load(sys.stdin); [change["change"].update(actions=[]) for change in plan["resource_changes"]]; json.dump(plan, sys.stdout)'
  ;;
*) exec "$opentofu/tofu" "\$@" ;;
esac
EOF
chmod +x "$emptied/tofu"
call_tool "$script_tools:$emptied" session-one propose staging-logs --opentofu infra/staging
expect "a resource change whose list of actions is empty makes the proposal wait" 0 \
  'The run waits for the owner.s go-ahead:'$'\n\n''- The plan does more than create, read or update these resources: `terraform_data\.credentials`, `terraform_data\.logging`, `terraform_data\.spare`\.'$'\n\n''On a go-ahead'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" switch -q --detach
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "a detached HEAD at the proposal" staging-logs infra/staging \
  'HEAD was detached at the proposal, so its action record has no branch to wait on\.' \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'
mutation session-one pending
expect "pending refuses a detached HEAD" 1 '^live-mutation\.py: detached-head: '

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
propose_tofu staging-logs --opentofu infra/staging
expect "a plan that changes nothing is refused" 1 '^live-mutation\.py: nothing-to-apply: the plan of infra/staging changes nothing'
if [[ ! -e "$repository/$proposals/staging-logs/proposal.json" ]]; then
  pass "a plan that changes nothing is no proposal"
else
  fail "a plan that changes nothing is no proposal" "it saved $proposals/staging-logs/proposal.json"
fi

expect_state() {
  local label=$1 root=$2 wanted=$3
  if [[ "$(state_of "$root")" == "$wanted" ]]; then
    pass "$label"
  else
    fail "$label" "the state of $root changed"
  fi
}

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
state=$(state_of infra/staging)
propose_tofu staging-swap --opentofu infra/staging \
  --check 'fresh=tofu -chdir=infra/staging plan -no-color -input=false -destroy -out="$LIVE_MUTATION_INPUTS/plan" >/dev/null; false'
expect "a check that writes a destroy plan over the frozen one while the proposal is made is refused" 1 \
  '^live-mutation\.py: inputs-changed: plan changed while the checks ran'
if [[ ! -e "$repository/$proposals/staging-swap/proposal.json" ]]; then
  pass "a check that rewrites the frozen plan leaves no proposal"
else
  fail "a check that rewrites the frozen plan leaves no proposal" "it saved $proposals/staging-swap/proposal.json"
fi

printf 'protected\n' >"$repository/production"
propose_tofu wipe --derive 'printf p >"$LIVE_MUTATION_INPUTS/plan"' --show 'printf "wipe production\n"' \
  --run 'printf "destroyed\n" >production'
edit_proposal wipe 'proposal["form"] = {"kind": "opentofu", "root": "infra/staging", "destroy": False, "checks": {}}'
tofu_mutation session-one run wipe "$digest"
expect "a proposal of the generic form edited to the OpenTofu form is refused" 1 \
  '^live-mutation\.py: corrupt: the digest of proposal wipe is not the one its commands, inputs and rendering give$'
if [[ "$(contents "$repository/production")" == protected ]]; then
  pass "a proposal edited to the OpenTofu form runs nothing"
else
  fail "a proposal edited to the OpenTofu form runs nothing" "production holds $(contents "$repository/production")"
fi

propose_tofu staging-logs --opentofu infra/staging
expect "an update-only plan needs no go-ahead before its inputs are swapped" 0 'The run needs no go-ahead: '
tofu_in infra/staging plan -input=false -destroy -out="$tmp/destroy.plan" >/dev/null
cp "$tmp/destroy.plan" "$repository/$proposals/staging-logs/inputs/plan"
swapped=$(sha256sum "$tmp/destroy.plan")
edit_proposal staging-logs 'proposal["inputs"]["plan"] = "'"${swapped%% *}"'"'
tofu_mutation session-one run staging-logs "$digest"
expect "a destroy plan copied over the frozen one, with its hash in the proposal, is refused" 1 \
  '^live-mutation\.py: corrupt: the digest of proposal staging-logs is not the one its commands, inputs and rendering give$'
expect_state "a destroy plan copied over the frozen one changes no state" infra/staging "$state"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
declared=$(git -C "$repository" rev-parse refs/remotes/origin/HEAD)
sed -i 's/"first"/"second"/' "$repository/infra/staging/main.tf"
propose_tofu staging-replace --opentofu infra/staging
edit_proposal staging-replace 'proposal["blocking"] = []; proposal["route"] = {"kind": "no-go-ahead-needed", "rule_file": ".claude/rules/sandbox.md", "commit": "'"$declared"'", "directory": "infra/staging"}'
expect_waits "a plan that replaces, whose saved route was edited to need no go-ahead" staging-replace infra/staging \
  'The plan does more than create, read or update these resources: `terraform_data\.logging`\.'

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" remote set-head origin --delete
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect "a proposal made while origin/HEAD is missing waits" 0 'The run waits for the owner.s go-ahead:'
git -C "$repository" remote set-head origin main
expect_waits "a proposal shown as waiting, run after origin/HEAD appears" staging-logs infra/staging \
  'The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

shown_waiting='The proposal was shown as waiting for the owner.s go-ahead, and such a proposal never runs without one\.'

new_tofu_repository
publish
rule mine.md "unprotected-roots:" "  - infra/staging"
git -C "$repository" add -A
git -C "$repository" commit -q -m "docs(rules): call staging unprotected"
git -C "$repository" push -q -u origin feat/staging-logs
git -C "$repository" remote set-head origin feat/staging-logs
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "origin/HEAD set to the agent's branch, which holds a rule" staging-logs infra/staging \
  '`refs/remotes/origin/HEAD` names `feat/staging-logs` at `'"$(git -C "$repository" rev-parse HEAD)"'`, while origin.s default branch is `main` at `'"$(git -C "$origin" rev-parse main)"'`\. Run `git fetch origin` and `git remote set-head origin --auto`, and propose again\.' \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
stale=$(git -C "$repository" rev-parse refs/remotes/origin/HEAD)
git clone -q "$origin" "$tmp/protects"
git -C "$tmp/protects" rm -q .claude/rules/sandbox.md
git -C "$tmp/protects" commit -q -m "docs(rules): protect staging again"
git -C "$tmp/protects" push -q origin main
rm -rf "$tmp/protects"
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "an origin/HEAD not fetched since origin removed the rule" staging-logs infra/staging \
  '`refs/remotes/origin/HEAD` names `main` at `'"$stale"'`, while origin.s default branch is `main` at `'"$(git -C "$origin" rev-parse main)"'`\. Run `git fetch origin` and `git remote set-head origin --auto`, and propose again\.' \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" remote set-url origin "$tmp/no-such-origin"
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "an origin that cannot be reached" staging-logs infra/staging \
  'origin cannot be reached, so the tool cannot read its default branch: `git ls-remote --symref origin HEAD` exited 128: '"$rest_of_line" \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" remote remove origin
git clone -q --bare "$origin" "$repository/origin"
git -C "$repository" update-ref refs/remotes/origin/main main
git -C "$repository" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "no remote named origin, beside a repository in the directory origin" staging-logs infra/staging \
  'No remote is named `origin`, since `git config --get remote.origin.url` prints nothing, so the tool cannot read its default branch\.' \
  "$shown_waiting"

new_tofu_repository
publish
rule mine.md "unprotected-roots:" "  - infra/staging"
git -C "$repository" add -A
git -C "$repository" commit -q -m "docs(rules): call staging unprotected"
git -C "$repository" replace refs/remotes/origin/main HEAD
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "origin's commit replaced by one of the agent's branch, which holds a rule" staging-logs infra/staging \
  'No rule file under `\.claude/rules/` at `'"$(git -C "$origin" rev-parse main)"'` lists `infra/staging` or a directory above it under `unprotected-roots:`\.' \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" switch -q main
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "a proposal on origin's default branch" staging-logs infra/staging \
  'HEAD is on `main`, the default branch of origin, so no pull request will take the action record\.' \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" switch -q main
git -C "$repository" tag main
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect_waits "a proposal on origin's default branch beside a tag of the same name" staging-logs infra/staging \
  'HEAD is on `main`, the default branch of origin, so no pull request will take the action record\.' \
  "$shown_waiting"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
git -C "$repository" switch -q -c feat/tracks-main --track origin/main
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect "a proposal on a branch started from origin's default branch, which it tracks, needs no go-ahead" 0 \
  'The run needs no go-ahead: '

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
tofu_in infra/staging workspace new production >/dev/null
tofu_in infra/staging apply -input=false -auto-approve >/dev/null
tofu_in infra/staging workspace select default >/dev/null
set_level infra/staging
default_state=$(state_of infra/staging)
environment=(TF_WORKSPACE=production)
propose_tofu staging-logs --opentofu infra/staging
expect_waits "TF_WORKSPACE set to another workspace of a declared root module" staging-logs \
  infra/staging/terraform.tfstate.d/production \
  'The workspace of `infra/staging` is `production`, and only its `default` workspace runs without a go-ahead, since a rule file declares a directory and not a workspace\.' \
  "$shown_waiting"
environment=()
expect_state "a run in the production workspace changes no state of the default one" infra/staging "$default_state"

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
environment=(TF_CLI_ARGS_plan=-var=level=from-the-environment)
propose_tofu staging-logs --opentofu infra/staging
expect_waits "TF_CLI_ARGS_plan set" staging-logs infra/staging \
  '`TF_CLI_ARGS_plan` is set, so tofu runs with arguments that the OpenTofu form does not write\.' \
  "$shown_waiting"
environment=()

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
environment=("TF_DATA_DIR=$repository/infra/staging/.terraform")
propose_tofu staging-logs --opentofu infra/staging
expect_waits "TF_DATA_DIR set" staging-logs infra/staging \
  '`TF_DATA_DIR` is set, so tofu reads a backend and a state that `-chdir` does not choose\.' \
  "$shown_waiting"
environment=()

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
mkdir -p "$repository/modules/notify"
printf '%s\n' 'resource "terraform_data" "notify" {' '  provisioner "local-exec" {' '    command = "printf ran >provisioned"' '  }' '}' \
  >"$repository/modules/notify/main.tf"
printf '%s\n' 'module "notify" {' '  source = "../../modules/notify"' '}' >"$repository/infra/staging/notify.tf"
printf '%s\n' 'resource "terraform_data" "announce" {' '  provisioner "local-exec" {' '    command = "printf ran >announced"' '  }' '}' \
  >"$repository/infra/staging/announce.tf"
tofu_in infra/staging init -input=false >/dev/null
propose_tofu staging-notify --opentofu infra/staging
expect_waits "a local-exec provisioner in the root module and in a module that a create-only plan calls" staging-notify \
  infra/staging \
  'A provisioner runs code that the plan does not show, and the configuration holds one in `terraform_data\.announce`, `module\.notify\.terraform_data\.notify`\.' \
  "$shown_waiting"

hidden='(sensitive value hidden by live-mutation.py)'
secrets=("$token")

expect_secrets_kept() {
  local label=$1 secret searched holders unexpected="" printed=""
  for secret in "${secrets[@]}"; do
    searched=0
    holders=$(grep -rlF --binary-files=text -e "$secret" "$repository/tmp/live-mutation") || searched=$?
    if ((searched > 1)); then
      unexpected+="grep exited $searched"$'\n'
    fi
    unexpected+=$(sed '\#/inputs/plan$#d' <<<"$holders")
    if [[ "$output" == *"$secret"* ]]; then
      printed+="$secret"$'\n'
    fi
  done
  if [[ -z "$unexpected" && -z "$printed" ]]; then
    pass "$label: neither the tool's output nor a file of the proposal but its saved plans holds a sensitive value"
  else
    fail "$label: neither the tool's output nor a file of the proposal but its saved plans holds a sensitive value" \
      "found in:"$'\n'"$unexpected"$'\n'"printed:"$'\n'"$printed"
  fi
}

carry_the_token_in_logging() {
  sed -i 's/^  input            = var\.level$/  input            = { level = var.level, token = var.token }/' \
    "$repository/infra/staging/main.tf"
}

new_tofu_repository
carry_the_token_in_logging
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
set_level infra/staging
propose_tofu staging-logs --opentofu infra/staging
expect "a rendering that shows the sensitive input of a terraform_data resource as its output stops the proposal" 1 \
  '^live-mutation\.py: sensitive-value-shown: '
expect_secrets_kept "a proposal stopped by its rendering"
rendering=$(contents "$repository/$proposals/staging-logs/rendering.txt")
if [[ "$rendering" == *"- token = \"$hidden\""* && ! -e "$repository/$proposals/staging-logs/proposal.json" ]]; then
  pass "a proposal stopped by its rendering is no proposal, and its rendering shows where the tool hid the value"
else
  fail "a proposal stopped by its rendering is no proposal, and its rendering shows where the tool hid the value" \
    "the rendering:"$'\n'"$rendering"
fi

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
propose_tofu staging-destroy --opentofu infra/staging --destroy
expect "a destroy of a terraform_data resource whose input holds a sensitive value stops the proposal" 1 \
  '^live-mutation\.py: sensitive-value-shown: '
expect_secrets_kept "a destroy stopped by its rendering"

copy_the_secrets_to_an_output() {
  cat >"$repository/infra/staging/copy.tf" <<'EOF'
variable "key" {
  type      = string
  sensitive = true
  default   = "-----BEGIN KEY-----\n  key-line-of-the-test\n-----END KEY-----\n"
}

variable "quoted" {
  type      = string
  sensitive = true
  default   = "a \"quoted\" value\u0001 of the test"
}

resource "terraform_data" "copy" {
  input = { token = var.token, key = var.key, quoted = var.quoted }
}

output "copy" {
  value = terraform_data.copy.output
}
EOF
}

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
copy_the_secrets_to_an_output
secrets=("$token" key-line-of-the-test $'"quoted" value\x01 of the test' '\"quoted\" value\x01 of the test')
propose_tofu staging-copy --opentofu infra/staging
expect "a plan that creates a terraform_data resource from sensitive inputs shows no sensitive value" 0 \
  'The run needs no go-ahead: '
tofu_mutation session-one run staging-copy "$digest"
expect "the apply prints the output of that resource, and the tool hides each sensitive value in it" 0 \
  "The run passes.*\"token\" = \"\\(sensitive value hidden by live-mutation\\.py\\)\""
tofu_mutation session-one record staging-copy
expect "the record of a run whose apply printed sensitive values is written" 0 'session-one/staging-copy/record-1\.md'
expect_secrets_kept "a run whose apply printed sensitive values, on one line, quoted and across lines"
secrets=("$token")
record=$(contents "$repository/$proposals/staging-copy/record-1.md")
if [[ "$record" == *"\"key\" = <<-EOT"$'\n'"  $hidden"$'\n'* && "$record" == *"\"quoted\" = \"$hidden\""* ]]; then
  pass "the record shows the output of the apply with each sensitive value hidden, a heredoc and a quoted string included"
else
  fail "the record shows the output of the apply with each sensitive value hidden, a heredoc and a quoted string included" \
    "got:"$'\n'"$record"
fi

new_tofu_repository
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
copy_the_secrets_to_an_output
stand_in=$tmp/outlives-the-tool
mkdir -p "$stand_in"
cat >"$stand_in/tofu" <<EOF
#!/bin/sh
case " \$* " in
*" apply "*)
  "$opentofu/tofu" "\$@" || exit
  : >"$repository/printed"
  while [ ! -e "$repository/go-on" ]; do $(command -v sleep) 0.1; done
  echo "printed after the tool ended"
  : >"$repository/finished"
  ;;
*) exec "$opentofu/tofu" "\$@" ;;
esac
EOF
chmod +x "$stand_in/tofu"
call_tool "$script_tools:$stand_in" session-one propose staging-copy --opentofu infra/staging
digest=$(sed -n 's/^Proposal `staging-copy` at digest `\([0-9a-f]*\)`.*/\1/p' <<<"$output")
(cd "$repository" && exec env -i PATH="$script_tools:$stand_in" CLAUDE_CODE_SESSION_ID=session-one "$script" run staging-copy "$digest" >/dev/null 2>&1) &
run_pid=$!
for _ in $(seq 600); do
  [[ -e "$repository/printed" ]] && break
  sleep 0.1
done
kill -KILL "$run_pid" 2>/dev/null || true
wait "$run_pid" || true
: >"$repository/go-on"
for _ in $(seq 600); do
  [[ -e "$repository/finished" ]] && break
  sleep 0.1
done
output="the tool was killed during the run"
if [[ -e "$repository/finished" ]]; then
  pass "a run whose tool is killed after the apply printed keeps its command running to the end"
else
  fail "a run whose tool is killed after the apply printed keeps its command running to the end" "the command never finished"
fi
secrets=("$token" key-line-of-the-test)
expect_secrets_kept "a run whose tool is killed after the apply printed sensitive values"
secrets=("$token")

new_tofu_repository
carry_the_token_in_logging
rule sandbox.md "unprotected-roots:" "  - infra/staging"
publish
sed -i 's/input = "spare"/input = "spare-two"/' "$repository/infra/staging/main.tf"
propose_tofu staging-spare --opentofu infra/staging
expect "a plan that leaves the terraform_data resource with the sensitive input alone shows no sensitive value" 0 \
  'The run needs no go-ahead: '
set_level infra/staging
state=$(state_of infra/staging)
tofu_mutation session-one run staging-spare "$digest"
expect "a rendering derived again that shows a sensitive value stops the run" 1 '^live-mutation\.py: sensitive-value-shown: '
expect_secrets_kept "a run stopped by the rendering derived again"
expect_state "a run stopped by the rendering derived again changes no state" infra/staging "$state"

if ((failures > 0)); then
  echo "test-live-mutation: $failures failure(s)" >&2
  exit 1
fi
