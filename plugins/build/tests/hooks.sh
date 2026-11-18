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

python_only=$tmp/python-only
mkdir -p "$python_only"
ln -s "$(PATH=$script_tools command -v python3)" "$python_only/python3"

# run_hook <hooks directory>: run its hook as a session does. Sets out, err, code.
run_hook() {
  code=0
  out=$(env -i PATH="$tools" HOME="$tmp" "$1/session-start.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

run_tool_hook() {
  local plugin_root=$1 tool=$2 tool_input=$3 fields=${4:-'{}'} path=${5:-$script_tools} commands command
  commands=$(jq -r --arg tool "$tool" '.hooks.PreToolUse[]? | select(.matcher as $matcher | $tool | test("^(\($matcher))$"))
    | .hooks[].command' "$plugin_root/hooks/hooks.json")
  jq -n --arg tool "$tool" --argjson tool_input "$tool_input" --argjson fields "$fields" \
    '{session_id: "s", hook_event_name: "PreToolUse", tool_name: $tool, tool_input: $tool_input, tool_use_id: "t"} + $fields' >"$tmp/stdin"
  code=0 out="" err=""
  while IFS= read -r command; do
    out+=$(env -i PATH="$path" CLAUDE_PLUGIN_ROOT="$plugin_root" "$tools/bash" -c "$command" <"$tmp/stdin" 2>"$tmp/stderr") || code=$?
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

route="An OpenTofu command that writes runs only through build:live-mutation. The lead invokes that skill and proposes the command with the skill's tool, which runs the apply of a saved plan on an unprotected root module without a go-ahead when it finds that it may, and every other write on the owner's go-ahead. A subagent stops and reports the command to its lead."

denied() {
  jq -n --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
}

writes() {
  denied "\`$1\` is an OpenTofu command that writes. $route"
}

hidden() {
  denied "This command names tofu, and the hook cannot tell what \`$1\` runs, since $2, so it denies it. Spell it out without a variable or a substitution there. $route"
}

unread() {
  denied "This command names tofu, and the hook cannot read it, since $1, so it denies it. $2 $route"
}

run_bash_hook() {
  run_tool_hook "$root" Bash "$(jq -n --arg command "$1" '{command: $command, description: "Run it"}')" "${@:2}"
}

tofu_denied() {
  local label=$1 command=$2 expected=$3
  run_bash_hook "$command" "${@:4}"
  check "tofu, $label: exits 0" equals "$code" 0
  check "tofu, $label: denied" json_equals "$out" "$expected"
}

tofu_runs() {
  local label=$1 command=$2
  run_bash_hook "$command" "${@:3}"
  check "tofu, $label: exits 0" equals "$code" 0
  check "tofu, $label: prints nothing, so it runs" equals "$out$err" ""
}

organization=infra/foundation/management/organization

for subcommand in "apply organization.tfplan" "apply -auto-approve" "destroy -auto-approve" \
  "import aws_organizations_organization.this o-abc123" "force-unlock 7f3c9a2e" "state rm aws_s3_bucket.logs" \
  "state mv aws_s3_bucket.logs aws_s3_bucket.audit" "state push organization.tfstate" \
  "state replace-provider hashicorp/aws registry.opentofu.org/hashicorp/aws" "refresh" "taint aws_s3_bucket.logs" \
  "untaint aws_s3_bucket.logs" "workspace delete staging" "init -migrate-state" "init --migrate-state" \
  "init -force-copy" "test" "workspace new staging" "workspace select -or-create staging"; do
  tofu_denied "$subcommand" "tofu $subcommand" "$(writes "tofu $subcommand")"
  tofu_denied "$subcommand after -chdir" "tofu -chdir=$organization $subcommand" \
    "$(writes "tofu -chdir=$organization $subcommand")"
done

for subcommand in "plan -input=false -out=organization.tfplan" "show -no-color organization.tfplan" "state list" \
  "state show aws_s3_bucket.logs" "state pull" "validate" "providers" "init -input=false" \
  "init -upgrade -backend-config=backend.hcl" "workspace select staging" "output -json" "version" \
  "apply -help" "import -h aws_s3_bucket.logs" "state rm --help" "state -lock=false rm aws_s3_bucket.logs"; do
  tofu_runs "$subcommand" "tofu $subcommand"
  tofu_runs "$subcommand after -chdir" "tofu -chdir=$organization $subcommand"
done

tofu_denied "apply after a cd" "cd $organization && tofu apply organization.tfplan" \
  "$(writes "tofu apply organization.tfplan")"
tofu_denied "apply with a variable assigned" "AWS_PROFILE=management tofu apply organization.tfplan" \
  "$(writes "AWS_PROFILE=management tofu apply organization.tfplan")"
tofu_denied "apply under aws-vault" "aws-vault exec management -- tofu -chdir=$organization apply organization.tfplan" \
  "$(writes "aws-vault exec management -- tofu -chdir=$organization apply organization.tfplan")"
tofu_denied "apply by the path of the program" "/nix/store/6knn-opentofu-1.12.6/bin/tofu destroy -auto-approve" \
  "$(writes "/nix/store/6knn-opentofu-1.12.6/bin/tofu destroy -auto-approve")"
tofu_denied "apply under nix run" "nix run nixpkgs#opentofu -- -chdir=$organization apply organization.tfplan" \
  "$(writes "nix run nixpkgs#opentofu -- -chdir=$organization apply organization.tfplan")"
tofu_denied "state rm under xargs" "xargs -n1 tofu state rm < addresses.txt" "$(writes "xargs -n1 tofu state rm")"
tofu_denied "apply in bash -c" "bash -c 'cd infra && tofu apply organization.tfplan'" \
  "$(writes "tofu apply organization.tfplan")"
tofu_denied "state rm in sh -ec" "sh -ec \"tofu state rm aws_s3_bucket.logs\"" \
  "$(writes "tofu state rm aws_s3_bucket.logs")"
tofu_denied "destroy in eval" "eval 'tofu destroy -auto-approve'" "$(writes "tofu destroy -auto-approve")"
tofu_denied "apply in a substitution" "echo \"\$(tofu apply -auto-approve)\"" "$(writes "tofu apply -auto-approve")"
tofu_denied "apply in a loop over directories" "for d in a b; do tofu -chdir=\"infra/\$d\" apply -auto-approve; done" \
  "$(writes "tofu -chdir=\"infra/\$d\" apply -auto-approve")"
tofu_denied "apply after an empty word, which tofu skips" "tofu '' apply" "$(writes "tofu '' apply")"

tofu_denied "a subcommand in a variable" "tofu -chdir=$organization \"\$subcommand\"" \
  "$(hidden "tofu -chdir=$organization \"\$subcommand\"" "its subcommand comes from a variable or a substitution")"
tofu_denied "a state subcommand in a variable" "tofu state \"\$operation\" aws_s3_bucket.logs" \
  "$(hidden "tofu state \"\$operation\" aws_s3_bucket.logs" "its subcommand comes from a variable or a substitution")"
tofu_denied "init with flags in a variable" "tofu init \$flags" \
  "$(hidden "tofu init \$flags" "an argument comes from a variable or a substitution and may be -force-copy or -migrate-state")"
tofu_denied "the program in a substitution" "\"\$(command -v tofu)\" apply organization.tfplan" \
  "$(hidden "\"\$(command -v tofu)\" apply organization.tfplan" "its program comes from a variable or a substitution")"
tofu_denied "the program in a variable of the environment" "\"\$TOFU\" -chdir=$organization plan" \
  "$(hidden "\"\$TOFU\" -chdir=$organization plan" "its program comes from a variable or a substitution")"
tofu_denied "the program in a variable assigned twice" "T=/bin/true; T=/nix/store/6knn-opentofu-1.12.6/bin/tofu; \$T apply" \
  "$(hidden "\$T apply" "its program comes from a variable or a substitution")"
tofu_denied "the program in a variable assigned the path of tofu" \
  "T=/nix/store/6knn-opentofu-1.12.6/bin/tofu; \$T -chdir=$organization apply organization.tfplan" \
  "$(writes "\$T -chdir=$organization apply organization.tfplan")"
tofu_denied "apply in bash -c, in double quotes with a variable" "bash -c \"cd \$dir && tofu apply organization.tfplan\"" \
  "$(writes "tofu apply organization.tfplan")"
tofu_denied "a subcommand in a variable, in eval" "eval \"tofu \$subcommand\"" \
  "$(hidden "tofu \$subcommand" "its subcommand comes from a variable or a substitution")"
tofu_denied "bash -c with a command partly in a variable" "bash -c \"tofu \"\$subcommand" \
  "$(hidden "bash -c \"tofu \"\$subcommand" "the command it hands a shell comes from a variable or a substitution")"

tofu_runs "plan in a loop over directories" "for d in a b; do tofu -chdir=\"infra/\$d\" plan; done"
tofu_runs "plan in nix shell" "nix shell nixpkgs#opentofu --command tofu -chdir=$organization plan"
tofu_runs "a commit message that names tofu apply" "git commit -m 'feat(build): deny tofu apply in Bash'"
tofu_runs "a search for tofu" "grep -rn tofu infra && command -v tofu"
tofu_runs "a search for tofu in a file named by a variable" \
  "f=/nix/store/vwn5-source/modules/hooks.nix; grep -n -i 'tofu' \"\$f\""
tofu_runs "init by the path of tofu in a variable" \
  "T=/nix/store/6knn-opentofu-1.12.6/bin/tofu; cd \"\$S/org\" && \$T init -backend=false -input=false"
tofu_runs "a program in a variable, and tofu apply in its arguments" \
  "T=plugins/build/skills/work-trace/scripts/trace.py && \$T append tmp/work-trace/x.tsv build 'ran tofu apply' 'ok'"
tofu_runs "plan in bash -c, in double quotes with a variable" \
  "for r in organization policies; do d=infra/foundation/management/\$r; devenv shell -- bash -c \"tofu -chdir=\$d init -input=false && tofu -chdir=\$d plan -input=false\"; done"
tofu_runs "nix eval, which is no eval" "nix eval --raw \"\$NP#legacyPackages.x86_64-linux.opentofu.version\""
tofu_runs "zsh, which does not parse as bash" "for f in \${=files}; do tofu -chdir=\"\$f\" validate; done"

live_mutation=$root/skills/live-mutation/scripts/live-mutation.py
tofu_runs "a proposal of build:live-mutation's tool" "$live_mutation propose import-organization \
  --derive 'tofu -chdir=$organization plan -input=false -out=\"\$LIVE_MUTATION_INPUTS/plan\"' \
  --show 'tofu -chdir=$organization show -no-color \"\$LIVE_MUTATION_INPUTS/plan\"' \
  --run 'tofu -chdir=$organization apply -input=false \"\$LIVE_MUTATION_INPUTS/plan\"' \
  --check 'no-changes=tofu -chdir=$organization plan -input=false -detailed-exitcode'"
tofu_runs "a run of build:live-mutation's tool" \
  "$live_mutation run import-organization 3f9a1c0d --go-ahead 'yes, run import-organization'"
tofu_runs "a proposal of build:live-mutation's tool in its OpenTofu form" \
  "$live_mutation propose staging-logs --opentofu infra/staging"
tofu_runs "a run of build:live-mutation's tool without a go-ahead" "$live_mutation run staging-logs 3f9a1c0d5e7b2a46"
tofu_runs "a proposal in the OpenTofu form of a root module under a directory named tofu" \
  "$live_mutation propose staging-logs --opentofu infra/tofu/staging --destroy"
tofu_runs "a proposal in the OpenTofu form of a root module named tofu" \
  "$live_mutation propose staging-logs --opentofu infra/tofu --check 'reachable=curl -fsS https://staging.example.com'"

subagent='{"agent_id": "a1", "agent_type": "general-purpose"}'
tofu_denied "apply in a subagent" "tofu -chdir=$organization apply organization.tfplan" \
  "$(writes "tofu -chdir=$organization apply organization.tfplan")" "$subagent"

reports="$(denied "A subagent never proposes, demonstrates or runs a live mutation with the tool of build:live-mutation, since only the lead can ask the owner for a go-ahead and only the lead has the standing instructions. Stop, and report to your lead the live mutation that your work needs.")"
tofu_denied "a proposal of build:live-mutation's tool in a subagent" \
  "$live_mutation propose staging-logs --opentofu infra/staging" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool without a go-ahead in a subagent" \
  "$live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool on a go-ahead in a subagent" \
  "$live_mutation run import-organization 3f9a1c0d --go-ahead 'yes, run import-organization'" "$reports" "$subagent"
tofu_denied "a demonstration of build:live-mutation's tool in a subagent" \
  "$live_mutation demonstrate staging-logs reachable 'curl -fsS https://other.example.com'" "$reports" "$subagent"
tofu_denied "a generic proposal of build:live-mutation's tool, by its quoted path, in a subagent" \
  "\"$live_mutation\" propose set-value --derive 'true' --show 'true' --run 'true'" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool under python3 in a subagent" \
  "python3 $live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool in bash -c in a subagent" \
  "bash -c '$live_mutation run staging-logs 3f9a1c0d5e7b2a46'" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool by a path in a variable in a subagent" \
  "\"\$CLAUDE_SKILL_DIR/scripts/live-mutation.py\" run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a subcommand of build:live-mutation's tool in a variable in a subagent" \
  "$live_mutation \"\$subcommand\" staging-logs" "$reports" "$subagent"
tofu_runs "pending of build:live-mutation's tool in a subagent" "$live_mutation pending" "$subagent"
tofu_runs "record of build:live-mutation's tool in a subagent" \
  "$live_mutation record staging-logs --session 20261110-0900-4000-8000-000000000150" "$subagent"
tofu_runs "a search of build:live-mutation's tool in a subagent" "grep -n 'def run' $live_mutation" "$subagent"
tofu_runs "a read of build:live-mutation's tool in a subagent" "cat $live_mutation" "$subagent"
tofu_runs "a diff of build:live-mutation's tool in a subagent" "git diff main -- $live_mutation" "$subagent"
tofu_denied "a run of build:live-mutation's tool after -- in a subagent" \
  "$live_mutation -- run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_runs "pending of build:live-mutation's tool after -- in a subagent" "$live_mutation -- pending" "$subagent"
tofu_denied "build:live-mutation's tool under xargs, its subcommand on standard input, in a subagent" \
  "echo 'run staging-logs 3f9a1c0d5e7b2a46' | xargs $live_mutation" "$reports" "$subagent"
tofu_denied "build:live-mutation's tool under xargs, its subcommand in a here-string, in a subagent" \
  "xargs $live_mutation <<<'run staging-logs 3f9a1c0d5e7b2a46'" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool in a heredoc fed to bash in a subagent" "bash <<'SH'
$live_mutation run staging-logs 3f9a1c0d5e7b2a46
SH" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool piped as text into sh in a subagent" \
  "echo '$live_mutation run staging-logs 3f9a1c0d5e7b2a46' | sh" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool under env in a subagent" \
  "env CLAUDE_CODE_SESSION_ID=s2 $live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool under timeout in a subagent" \
  "timeout 600 $live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool under nix shell --command in a subagent" \
  "nix shell nixpkgs#opentofu --command $live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool under a program in a variable in a subagent" \
  "\"\$PYTHON\" $live_mutation run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "build:live-mutation's tool under xargs -I, its subcommand replaced from standard input, in a subagent" \
  "echo run | xargs -I{} $live_mutation {} staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "a run of build:live-mutation's tool in a here-string fed to bash in a subagent" \
  "bash <<<'$live_mutation run staging-logs 3f9a1c0d5e7b2a46'" "$reports" "$subagent"
tofu_denied "an alias of build:live-mutation's tool, used to run, in a subagent" \
  "alias lm=$live_mutation; lm run staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_denied "an alias of a run of build:live-mutation's tool in a subagent" \
  "alias lm='$live_mutation run'; lm staging-logs 3f9a1c0d5e7b2a46" "$reports" "$subagent"
tofu_runs "a lint of build:live-mutation's tool by ruff in a subagent" "ruff check $live_mutation" "$subagent"
tofu_runs "a type check of build:live-mutation's tool by basedpyright in a subagent" \
  "basedpyright $live_mutation" "$subagent"
tofu_runs "a compile of build:live-mutation's tool by python3 -m py_compile in a subagent" \
  "python3 -m py_compile $live_mutation" "$subagent"
tofu_runs "a copy of build:live-mutation's tool to a path in a variable in a subagent" \
  "cp $live_mutation \"\$scratch/live-mutation.py\"" "$subagent"
tofu_runs "a search for run in build:live-mutation's tool in a subagent" "grep -n run $live_mutation" "$subagent"
tofu_runs "a script file run by bash, then a search of build:live-mutation's tool, in a subagent" \
  "bash plugins/build/tests/live-mutation.sh && grep -n run $live_mutation" "$subagent"
tofu_runs "build:live-mutation's tool under xargs, by the lead" \
  "echo 'run staging-logs 3f9a1c0d5e7b2a46' | xargs $live_mutation"
tofu_runs "a run of build:live-mutation's tool in a heredoc fed to bash, by the lead" "bash <<'SH'
$live_mutation run staging-logs 3f9a1c0d5e7b2a46
SH"
tofu_runs "a run of build:live-mutation's tool in a here-string fed to bash, by the lead" \
  "bash <<<'$live_mutation run staging-logs 3f9a1c0d5e7b2a46'"
tofu_runs "a run of build:live-mutation's tool under timeout, by the lead" \
  "timeout 600 $live_mutation run staging-logs 3f9a1c0d5e7b2a46"
tofu_runs "an alias of build:live-mutation's tool, used to run, by the lead" \
  "alias lm=$live_mutation; lm run staging-logs 3f9a1c0d5e7b2a46"

tofu_denied "plan without shfmt on the PATH" "tofu -chdir=$organization plan" \
  "$(unread "shfmt, which parses it, is not on the PATH that Claude Code gives its hooks" "Ask the operator to start Claude Code from the repository's devenv shell, whose lyngon.scriptTools provide shfmt.")" \
  '{}' "$python_only"
tofu_runs "a command that names no tofu, without shfmt on the PATH" "git status --short" '{}' "$python_only"
tofu_runs "a path with tofu inside a longer name, without shfmt on the PATH" \
  "cd /home/ada/Projects/issue-145-tofu-writes-denied/infra/tofu-modules && git status --short" '{}' "$python_only"
tofu_denied "the program in a variable named for tofu" "\"\$TOFU_BIN\" -chdir=$organization apply organization.tfplan" \
  "$(hidden "\"\$TOFU_BIN\" -chdir=$organization apply organization.tfplan" "its program comes from a variable or a substitution")"
tofu_denied "a command that parses neither as bash nor as zsh" "tofu -chdir=$organization plan; fi" \
  "$(unread "it parses neither as bash nor as zsh" "Write it as bash.")"

run_tool_hook "$root" Monitor '{"command": "tofu apply -auto-approve", "description": "Apply", "timeout_ms": 60000}'
check "tofu, apply in Monitor: denied" json_equals "$out" "$(writes "tofu apply -auto-approve")"
run_tool_hook "$root" Monitor '{"ws": {"url": "wss://events.example.com/stream"}, "description": "Deploy events", "timeout_ms": 60000}'
check "tofu, a Monitor on a WebSocket: prints nothing, so it runs" equals "$out$err" ""

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
  out=$(env -i PATH="$python_only" CLAUDE_PLUGIN_ROOT="$root" "$tools/bash" -c "$mode_command" <"$tmp/stdin" 2>"$tmp/stderr") || code=$?
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
lead_command_refused ">& to a file, which writes both outputs there" \
  "python3 -m unittest discover tests >&tests/run.log" ">&tests/run.log"
lead_command_refused ">&3-, which bash reads as a move of descriptor 3 and zsh as a write of the file 3-" \
  "exec 3>&1; python3 -m unittest discover tests >&3-" ">&3-"
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
lead_command_refused "rm in backquotes" "echo \`rm tests/test_pricing.py\`" "rm tests/test_pricing.py"
lead_command_refused "rm after a keyword" "if true; then rm tests/test_pricing.py; fi" "rm tests/test_pricing.py"
lead_command_refused "rm under sudo" "sudo rm tests/test_pricing.py" "rm tests/test_pricing.py"
lead_command_refused "git rm" "git rm -q tests/test_pricing.py" "rm -q tests/test_pricing.py"
lead_command_refused "rm with its file on the next line" "rm -f \\
  tests/test_pricing.py" "rm -f \\
  tests/test_pricing.py"
lead_command_refused "rm of a file named ';'" "rm ';' README.md" "rm ';' README.md"
lead_command_refused "a redirection after a word that holds #" "nix run nixpkgs#hello > README.md" "> README.md"
lead_command_refused "sed -i in a zsh loop, which does not parse as bash" \
  "for f in \${=files}; do sed -i 's/a/b/' \"\$f\"; done" "sed -i 's/a/b/' \"\$f\""

unread_command() {
  jq -n --arg why "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "In /build:auto the lead writes no code, and the hook cannot read this command, since \($why), so it cannot tell what it writes. Write the command without that construct. Start a build:implementer delegate (subagent_type \"build:implementer\") with a brief that names the file, and review its diff. The lead writes, by any tool, only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it, and its command names such a file by a path without a variable or a substitution."}}'
}

lead_command_unread() {
  local label=$1 command=$2 why=$3
  run_lead_command "$command"
  check "the lead's command, $label: exits 0" equals "$code" 0
  check "the lead's command, $label: refused, saying why it cannot read it" json_equals "$out" "$(unread_command "$why")"
}

lead_command_unread "a quote that is not closed" "echo 'it is > README.md" "a ' is not closed"
lead_command_unread "a case statement in a substitution" \
  "echo \"\$(case x in x) rm README.md;; esac)\"" "it holds a case statement inside parentheses"
lead_command_unread "a here-document without its end line" "cat > tmp/notes.md <<'EOF'
notes" "no line EOF ends its here-document"
lead_command_unread "a quote inside a zsh expansion" "print -l \${(f)\"\$(ls)\"}" "a \${...} holds a quote"

lead_command_runs "the full check" "devenv test"
lead_command_runs "the full check, its output kept under tmp/" "devenv test > tmp/check.log 2>&1"
lead_command_runs ">& to a file descriptor" "echo 'no remote' >&2; exec 3>&1; ls 1>&3 3>&-"
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
lead_command_runs "reads that send errors to /dev/null" \
  "cd /recorded/orders 2>/dev/null; pwd; find / -maxdepth 6 -iname \"orders\" -type d 2>/dev/null"
lead_command_runs "a read with a substitution" \
  "gh pr view feat/bulk-discount 2>&1 || gh pr view \$(git rev-parse --abbrev-ref HEAD) 2>&1"
lead_command_runs "a proposal of build:live-mutation's tool" "python3 $root/skills/live-mutation/scripts/live-mutation.py propose bulk-discount \\
  --derive 'cloudctl plan production --out \"\$LIVE_MUTATION_INPUTS/plan\"' \\
  --check 'replicas=cloudctl get production service.orders | python3 -c \"import json,sys;sys.exit(json.load(sys.stdin)[\\\"replicas\\\"]!=3)\"' \\
  2>&1"
lead_command_runs "a comment that names a write" "git status --short # then > README.md"
lead_command_runs "comparisons in arithmetic" "echo \$(( 3 > 2 )); (( 10 >= 9 )) && echo bulk"
lead_command_runs "a search for the name of a writer" "grep -rn 'sed -i' src | head -5"

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

auditor_matcher=$(jq -r '.hooks.PreToolUse[] | select(.hooks[].command | contains("/hooks/auditor-deletes-only-comments.py")) | .matcher' "$root/hooks/hooks.json")
check "the auditor's hook matches the tools that write files" equals "$auditor_matcher" "Edit|Write|NotebookEdit|Bash"

auditor='{"agent_id": "a2", "agent_type": "build:comment-auditor"}'
cache=$repository/rates/cache.py
fetch=$repository/rates/fetch.sh
module=$repository/rates/default.nix
mkdir -p "$repository/rates"
cat >"$cache" <<'EOF'
"""Keep each rate that the provider returned for ten minutes."""

import time

TTL_SECONDS = 600  # ten minutes
LIMITS = "https://rates.example.com/docs/errors#rate-limits"


class RateCache:
    def get(self, base: str, quote: str) -> float | None:
        """Return the cached rate of the pair, or None when it is missing or stale."""
        entry = self._entries.get((base, quote))
        if entry is None:
            return None
        # put() only ever stores a tuple, so this never happens, but it is
        # kept just in case an entry of another shape ever gets in.
        if not isinstance(entry, tuple):
            return None
        fetched_at, rate = entry
        if time.monotonic() - fetched_at > TTL_SECONDS:
            return None
        return rate
EOF
cat >"$fetch" <<'EOF'
#!/usr/bin/env bash
pairs=$#  # the number of pairs
cat <<'END'
# a line that cat prints
END
EOF
cat >"$module" <<'EOF'
{ pairs }:
{
  /* the provider's API */ url = "https://rates.example.com/v1#latest";
}
EOF
printf '{"nodes": {}}\n' >"$repository/devenv.lock"
printf '# \xff\nx = 1\n' >"$repository/rates/latin1.py"
cache_text=$(<"$cache")

dead_branch_with_its_excuse='        if entry is None:
            return None
        # put() only ever stores a tuple, so this never happens, but it is
        # kept just in case an entry of another shape ever gets in.
        if not isinstance(entry, tuple):
            return None
        fetched_at, rate = entry'
dead_branch_deleted='        if entry is None:
            return None
        fetched_at, rate = entry'
dead_branch_alone='        if entry is None:
            return None
        if not isinstance(entry, tuple):
            return None
        fetched_at, rate = entry'

edit() {
  jq -n --arg path "$1" --arg old "$2" --arg new "$3" '{file_path: $path, old_string: $old, new_string: $new}'
}

run_auditor_hook() {
  local tool=$1 tool_input=$2 agent=${3:-$auditor} path=${4:-$script_tools}
  run_tool_hook "$root" "$tool" "$tool_input" "$(jq -c --arg cwd "$repository" '. + {cwd: $cwd}' <<<"$agent")" "$path"
}

audit_refused() {
  local label=$1 reason=$2
  check "the auditor's $label: exits 0" equals "$code" 0
  check "the auditor's $label: refused" json_equals "$out" "$(denied "$reason")"
}

audit_runs() {
  local label=$1
  check "$label: exits 0" equals "$code" 0
  check "$label: prints nothing, so it runs" equals "$out$err" ""
}

changes_code() {
  echo "build:comment-auditor deletes comments and changes no code, and this $1 changes the code of $2: $3. Make the edit again with only comments deleted, and leave the code as it is, also code that never runs. Where a deleted comment covered for that code, mark the code MUST KILL in your report."
}

unchecked() {
  echo "build:comment-auditor deletes comments and changes no code, and this hook cannot check an edit of $1, since $2. Leave its comments as they are, and report them skipped."
}

through_the_shell() {
  echo "build:comment-auditor deletes comments and changes no code. It deletes comments with Edit, whose edits this hook checks, and writes through the shell into no repository, so it may not write through \`$1\`. This hook counts a file that a path with a variable or a substitution names as one inside a repository."
}

run_auditor_hook Edit "$(edit "$cache" "$dead_branch_with_its_excuse" "$dead_branch_deleted")"
audit_refused "Edit that deletes a dead branch with the comment that excused it, as in issue 135" \
  "$(changes_code Edit "$cache" "it removes the code \`if not isinstance(entry, tuple):\`")"

run_auditor_hook Edit "$(edit "$cache" "$dead_branch_with_its_excuse" "$dead_branch_alone")"
audit_runs "the auditor's Edit that deletes only that comment"

run_auditor_hook Edit "$(edit "$cache" "$dead_branch_with_its_excuse" "$dead_branch_deleted")" \
  '{"agent_id": "a3", "agent_type": "build:implementer"}'
audit_runs "a delegate's Edit that deletes the dead branch"

run_auditor_hook Edit "$(edit "$cache" "$dead_branch_with_its_excuse" "$dead_branch_deleted")" '{}'
audit_runs "the lead's Edit that deletes the dead branch"

run_auditor_hook Edit "$(edit "$cache" '        """Return the cached rate of the pair, or None when it is missing or stale."""
' '')"
audit_runs "the auditor's Edit that deletes a docstring"

run_auditor_hook Edit "$(edit "$cache" 'TTL_SECONDS = 600  # ten minutes' 'TTL_SECONDS = 600')"
audit_runs "the auditor's Edit that deletes a comment at the end of a line"

run_auditor_hook Edit "$(edit "$cache" 'errors#rate-limits"' 'errors"')"
audit_refused "Edit of a string that holds a #" \
  "$(changes_code Edit "$cache" "it changes the code \`LIMITS = \"https://rates.example.com/docs/errors#rate-limits\"\` to \`LIMITS = \"https://rates.example.com/docs/errors\"\`")"

run_auditor_hook Edit "$(edit "$cache" '            return None
        fetched_at' '        return None
        fetched_at')"
audit_refused "Edit that indents a line less" \
  "$(changes_code Edit "$cache" "it changes the indentation of the code \`return None\`")"

run_auditor_hook Write "$(jq -n --arg path "$cache" --arg content "${cache_text/"$dead_branch_with_its_excuse"/"$dead_branch_alone"}" '{file_path: $path, content: $content}')"
audit_runs "the auditor's Write of the file without that comment"

run_auditor_hook Write "$(jq -n --arg path "$cache" --arg content "${cache_text/"$dead_branch_with_its_excuse"/"$dead_branch_deleted"}" '{file_path: $path, content: $content}')"
audit_refused "Write of the file without the dead branch" \
  "$(changes_code Write "$cache" "it removes the code \`if not isinstance(entry, tuple):\`")"

run_auditor_hook Write "$(jq -n --arg path "$repository/rates/limits.py" '{file_path: $path, content: "LIMIT = 10\n"}')"
audit_refused "Write of a new file" "$(changes_code Write "$repository/rates/limits.py" "it adds the code \`LIMIT = 10\`")"

run_auditor_hook Edit "$(edit "$fetch" 'pairs=$#  # the number of pairs' 'pairs=$#')"
audit_runs "the auditor's Edit that deletes a shell comment after \$#"

run_auditor_hook Edit "$(edit "$fetch" "# a line that cat prints
" '')"
audit_refused "Edit of a line of a here-document that starts with #" \
  "$(changes_code Edit "$fetch" "it changes the code \`cat <<'END'
# a line that cat prints
END\` to \`cat <<'END'
END\`")"

run_auditor_hook Edit "$(edit "$module" "/* the provider's API */ " '')"
audit_runs "the auditor's Edit that deletes a Nix block comment before code"

client=$repository/rates/client.ts
settings=$repository/rates/settings.yaml
readme=$repository/rates/README.md
printf '%s\n' 'const url = "https://rates.example.com//v1"; // the provider' 'const slashes = /\/\//;' >"$client"
printf '%s\n' 'ttl: 600 # seconds' 'run: |' '  echo fetched # a line of the script' >"$settings"
printf '%s\n' '# Rates' '' '<!-- a note -->' 'Fetches rates.' >"$readme"

run_auditor_hook Edit "$(edit "$client" '; // the provider' ';')"
audit_runs "the auditor's Edit that deletes a TypeScript comment after a string that holds //"

run_auditor_hook Edit "$(edit "$client" '/\/\//' '/\//')"
audit_refused "Edit of a regular expression that holds //" \
  "$(changes_code Edit "$client" "it changes the code \`const slashes = /\\/\\//;\` to \`const slashes = /\\//;\`")"

run_auditor_hook Edit "$(edit "$settings" 'ttl: 600 # seconds' 'ttl: 600')"
audit_runs "the auditor's Edit that deletes a YAML comment"

run_auditor_hook Edit "$(edit "$settings" ' # a line of the script' '')"
audit_refused "Edit of a block scalar, whose # is no YAML comment" \
  "$(changes_code Edit "$settings" "it changes the code \`echo fetched # a line of the script\` to \`echo fetched\`")"

run_auditor_hook Edit "$(edit "$readme" '<!-- a note -->
' '')"
audit_refused "Edit that deletes an HTML comment from Markdown, which Pygments lexes as text" \
  "$(changes_code Edit "$readme" "it removes the code \`<!-- a note -->\`")"

run_auditor_hook Edit "$(edit "$repository/devenv.lock" '{}' '{"x": 1}')"
audit_refused "Edit of a file that Pygments knows no language of" \
  "$(unchecked "$repository/devenv.lock" "Pygments knows no language by its file name")"

run_auditor_hook Edit "$(edit "$repository/rates/latin1.py" 'x = 1' 'x = 2')"
audit_refused "Edit of a file that is not UTF-8" "$(unchecked "$repository/rates/latin1.py" "it is not UTF-8 text")"

run_auditor_hook NotebookEdit '{"notebook_path": "'"$repository/analysis.ipynb"'", "new_source": "x = 1"}'
audit_refused "NotebookEdit" "$(unchecked "$repository/analysis.ipynb" "it is a notebook")"

run_auditor_hook Edit "$(edit "$cache" "$dead_branch_with_its_excuse" "$dead_branch_alone")" "$auditor" "$python_only"
audit_refused "Edit without pygmentize on the PATH" \
  "$(unchecked "$cache" "pygmentize, which tells comments from code, is not on the PATH that Claude Code gives its hooks")"

run_auditor_hook Edit "$(edit "$cache" '# no such comment' '')"
audit_refused "Edit whose old_string is not in the file" \
  "build:comment-auditor deletes comments and changes no code, and this hook cannot apply this Edit to $cache to check it, since its old_string is not in the file as many times as the Edit needs. Read the file, and give old_string as it stands there."

run_auditor_hook Edit "$(edit "$outside_any_repository/notes.py" 'x = 1' 'x = 2')"
audit_runs "the auditor's Edit outside any repository"

auditor_command() {
  run_auditor_hook Bash "$(jq -n --arg command "$1" '{command: $command, description: "Run it"}')"
}

auditor_command "sed -i '/^ *#/d' rates/cache.py"
audit_refused "sed -i" "$(through_the_shell "sed -i '/^ *#/d' rates/cache.py")"

auditor_command "cat > rates/cache.py <<'EOF'
x = 1
EOF"
audit_refused "heredoc into a file" "$(through_the_shell "> rates/cache.py")"

auditor_command "for f in rates/*.py; do perl -ni -e 'print unless /^\s*#/' \"\$f\"; done"
audit_refused "perl -i on a path in a variable" "$(through_the_shell "perl -ni -e 'print unless /^\s*#/' \"\$f\"")"

auditor_command "echo 'it is > rates/cache.py"
audit_refused "command that the hook cannot read" \
  "build:comment-auditor deletes comments and changes no code. It deletes comments with Edit, whose edits this hook checks, and writes through the shell into no repository, and this hook cannot read this command, since a ' is not closed, so it cannot tell what it writes. Write the command without that construct."

auditor_command "git log --oneline -5 -- rates/cache.py && git blame -L 15,18 rates/cache.py && grep -n '#' rates/*.py"
audit_runs "the auditor's reads through git and grep"

auditor_command "echo x > $outside_any_repository/notes.md"
audit_runs "the auditor's write outside any repository"

if ((failures > 0)); then
  echo "test-build-hooks: $failures failure(s)" >&2
  exit 1
fi
echo "test-build-hooks: ok"
