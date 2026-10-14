#!/usr/bin/env bash
# Exercise compare-evals.py against throwaway git repositories, with a stub in
# place of Claude Code, so that no test calls a model. The stub answers
# `claude plugin eval` with the file canned-result.json of the checkout it
# runs in, which differs between the two commits of a fixture. Run through
# `devenv test`.
set -euo pipefail

program=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/compare-evals.py
tmp=$(mktemp -d)
# A sandbox that the stub kept is read-only, as the real one is.
remove() {
  [[ ! -e "$1" ]] || chmod -R u+rwx "$1"
  rm -rf "$1"
}
trap 'remove "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

# --- The stub ----------------------------------------------------------------

# The stub does what the real command was measured to do on Claude Code
# 2.1.283. It writes aggregate-result.json and its report into the directory
# that --output-dir names, and exits with the status the checkout asks for
# after it wrote the result. It prints the file canned-progress of the
# checkout on stderr and a table on stdout, unless --json names a file: then
# it writes the result there too and prints neither. A run that ended in an
# error leaves its sandbox in the temporary directory, read-only, unless
# --json names a file.
#
# A checkout without a canned result stands for a run that dies before it
# writes one. A canned result without a case stands for a filter that matches
# none: the stub says so and writes a result only where --json names a file.
# A checkout with the file canned-hang stands for a run that never ends: the
# stub writes its process ID to the file that FAKE_CLAUDE_PID names and stays.
mkdir "$tmp/bin" "$tmp/tools" "$tmp/empty"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$PWD" "$*" >>"$FAKE_CLAUDE_LOG"
json="" output=evals/results/stub filter=""
while (($# > 0)); do
  case "$1" in
    --json)
      json=$2
      shift
      ;;
    --output-dir)
      output=$2
      shift
      ;;
    --case)
      filter=" matching --case \"$2\""
      shift
      ;;
  esac
  shift
done
if [[ -f canned-hang ]]; then
  echo "$$" >"$FAKE_CLAUDE_PID"
  exec sleep 1000
fi
[[ -f canned-result.json ]] || exit 1
if jq -e '.cases == []' canned-result.json >/dev/null 2>&1; then
  echo "No eval cases found$filter under $PWD." >&2
  [[ -z $json ]] || cp canned-result.json "$json"
  exit 1
fi
if [[ -z $json ]]; then
  [[ ! -f canned-progress ]] || echo "$(<canned-progress)" >&2
  if jq -e '[.cases[]?.arms.with[]?.error // empty] != []' canned-result.json >/dev/null 2>&1; then
    kept=$(mktemp -d "${TMPDIR:-/tmp}/claude-eval-XXXXXX")
    mkdir -p "$kept/sealed/home"
    echo "written by the plugin under test" >"$kept/sealed/home/notes.md"
    chmod 000 "$kept/sealed"
    chmod 500 "$kept"
    echo "  kept temp (run failed): $kept" >&2
  fi
fi
mkdir -p "$output"
cp canned-result.json "$output/aggregate-result.json"
echo "<html></html>" >"$output/report.html"
if [[ -n $json ]]; then
  cp canned-result.json "$json"
else
  echo "CASE  SCORE PASS% RUNS COST  NOTES"
fi
echo "Report: $output/report.html" >&2
[[ ! -f canned-exit ]] || exit "$(<canned-exit)"
EOF
chmod +x "$tmp/bin/claude"
export FAKE_CLAUDE_LOG=$tmp/claude.log FAKE_CLAUDE_PID=$tmp/claude.pid

# The program and the stub run with these tools and no others, so that no test
# can reach the real Claude Code, whatever the PATH of the shell that runs it.
for tool in bash chmod cp env git jq mkdir mktemp python3 sleep; do
  ln -s "$(command -v "$tool")" "$tmp/tools/$tool"
done
with_claude=$tmp/bin:$tmp/tools
without_claude=$tmp/tools
path=$with_claude

# --- Fixture helpers ---------------------------------------------------------

# run_of <error>: one run of a case, as the result file holds it.
run_of() {
  jq -n --arg error "$1" '{score: 0, passed: false, error: (if $error == "" then null else $error end), graders: []}'
}

# case_of <dir> <score> <runs> [<error>]: one case with that many runs.
case_of() {
  jq -n --arg dir "$1" --argjson score "$2" --argjson runs "$3" --argjson run "$(run_of "${4:-}")" \
    '{name: ($dir | split("/") | last), dir: $dir, arms: {with: [range($runs) | $run]}, aggregates: {score: $score, passRate: $score}}'
}

# with_grader <name> <verdicts>: the case on stdin with one more grader in its
# runs. The verdicts hold one letter for each run, p for passed and f for
# failed.
with_grader() {
  jq --arg name "$1" --arg verdicts "$2" \
    '.arms.with |= [to_entries[] | .value.graders += [{name: $name, passed: ($verdicts[.key:.key + 1] == "p")}] | .value]'
}

# result <cost> <case>...: a whole result file.
result() {
  local cost=$1
  shift
  printf '%s\n' "$@" | jq -s --argjson cost "$cost" '{schemaVersion: 1, costUsd: $cost, partial: false, cases: .}'
}

# progress_of <case name> [<line about the case as a whole>...]: what the real
# command prints on stderr for a case with one run, copied from a run on
# Claude Code 2.1.283. Its lines about the case as a whole come first, such
# as a gated tool that the case lists and the run did not grant, then the run
# with its graders, then the verdict.
progress_of() {
  local name=$1 line
  shift
  for line in "$@"; do
    echo "  $name: $line"
  done
  cat <<EOF
  $name run 1/1: score 1.00  \$0.07
    ✓ names-with-objections (weight 1): judge votes: PASS PASS PASS
    ✓ no-file-written (weight 1): **/* absent as expected
✓ $name  score 1.00  (1 run)  \$0.07
EOF
}

commit() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

# A repository of two commits, each with its own canned result: a case that
# goes from red to green, one that exists only at the first commit, one whose
# score drops over three runs as its graders start to fail, and one that
# exists only at the second. Neither run says anything about a case as a
# whole. The tag `base` names the first commit.
two_commits() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q -b main
  result 0.25 \
    "$(case_of plugins/one/evals/red-then-green 0 1 | with_grader writes-the-file f)" \
    "$(case_of plugins/one/evals/removed-at-head 1 1 | with_grader writes-the-file p)" \
    "$(case_of plugins/one/evals/stays-green 1 3 | with_grader names-it ppp | with_grader asks-first ppp)" >"$repo/canned-result.json"
  progress_of removed-at-head >"$repo/canned-progress"
  commit "$repo" "chore: base"
  git -C "$repo" tag base
  result 0.5 \
    "$(case_of plugins/two/evals/new-at-head 1 1 | with_grader writes-the-file p)" \
    "$(case_of plugins/one/evals/stays-green 0.6666666666666666 3 | with_grader names-it pff | with_grader asks-first fpp)" \
    "$(case_of plugins/one/evals/red-then-green 1 1 | with_grader writes-the-file p)" >"$repo/canned-result.json"
  progress_of new-at-head >"$repo/canned-progress"
  commit "$repo" "chore: head"
  echo "$repo"
}

sha() {
  git -C "$1" rev-parse "$2"
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
    echo "  expected: ${2//$'\n'/$'\n'            }"
    echo "  actual:   ${1//$'\n'/$'\n'            }"
    return 1
  }
}

# A needle may span lines, which grep would read as one pattern for each line.
contains() {
  [[ "$1" == *"$2"* ]] || {
    echo "  missing: ${2//$'\n'/$'\n'           }"
    echo "  in:      ${1//$'\n'/$'\n'           }"
    return 1
  }
}

lacks() {
  [[ "$1" != *"$2"* ]] || {
    echo "  unexpected: $2"
    return 1
  }
}

# gone <process ID>: no such process runs any more.
gone() {
  ! kill -0 "$1" 2>/dev/null
}

# compare <repo> <argument>...: run the program in the repository, capturing
# stdout, stderr and the exit code in out, err and code, and the stub's calls
# in calls. Temporary files go to an empty directory of their own.
compare() {
  local repo=$1
  shift
  remove "$tmp/scratch" && mkdir "$tmp/scratch"
  : >"$FAKE_CLAUDE_LOG"
  code=0
  out=$(cd "$repo" && TMPDIR=$tmp/scratch PATH=$path "$program" "$@" 2>"$tmp/stderr" </dev/null) || code=$?
  err=$(<"$tmp/stderr")
  calls=$(<"$FAKE_CLAUDE_LOG")
}

# The stub's calls from inside the repository, and from outside it.
calls_in() {
  grep -F -- "$1"$'\t' <<<"$calls" || true
}

calls_outside() {
  grep -vF -- "$1"$'\t' <<<"$calls" || true
}

nothing_left() {
  local repo=$1
  equals "$(git -C "$repo" worktree list | wc -l)" 1 &&
    equals "$(git -C "$repo" status --porcelain)" "" &&
    equals "$(ls -A "$tmp/scratch")" ""
}

# --- Cases -------------------------------------------------------------------

repo=$(two_commits)
compare "$repo" main~1
check "two commits: exits 0" equals "$code" 0
check "two commits: prints each case with its score and runs at base and at head, then the graders that failed" equals "$out" "base: $(sha "$repo" main~1) (main~1)
head: $(sha "$repo" main)
granted tools: none

case                               base           head
plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)
plugins/one/evals/removed-at-head  1.00 (1 run)   -
plugins/one/evals/stays-green      1.00 (3 runs)  0.67 (3 runs)
plugins/two/evals/new-at-head      -              1.00 (1 run)

plugins/one/evals/red-then-green at base: grader writes-the-file failed in 1 of 1 runs
plugins/one/evals/stays-green at head: grader names-it failed in 2 of 3 runs
plugins/one/evals/stays-green at head: grader asks-first failed in 1 of 3 runs

cost: base 0.25 USD, head 0.50 USD"
check "two commits: the progress of a run reaches stderr" contains "$err" "
  new-at-head run 1/1: score 1.00  \$0.07
    ✓ names-with-objections (weight 1): judge votes: PASS PASS PASS
    ✓ no-file-written (weight 1): **/* absent as expected
✓ new-at-head  score 1.00  (1 run)  \$0.07
"
check "two commits: what a run prints on stdout reaches stderr" contains "$err" "
CASE  SCORE PASS% RUNS COST  NOTES
"
check "two commits: one run at head, in the working tree" equals "$(calls_in "$repo" | wc -l)" 1
check "two commits: one run at base, outside the working tree" equals "$(calls_outside "$repo" | wc -l)" 1
check "two commits: the head run is the suite of the checkout, unpublished, without a baseline arm" \
  contains "$(calls_in "$repo")" "plugin eval . "
for flag in "--no-publish" "--ablation none" "--trust-plugin" "--scaffold"; do
  check "two commits: the head run passes $flag" contains "$(calls_in "$repo")" "$flag"
  check "two commits: the base run passes $flag" contains "$(calls_outside "$repo")" "$flag"
done
check "two commits: no filter and no grant unless asked" lacks "$calls" "--case"
check "two commits: no grant unless asked" lacks "$calls" "--allow-tools"
check "two commits: nothing is left behind" nothing_left "$repo"

repo=$(two_commits)
compare "$repo" "$(sha "$repo" main~1)" --case 'red-*' --allow-tools Write 'Bash(git:*)' --runs 1 --model sonnet
check "options: exits 0" equals "$code" 0
for option in "--case red-*" "--allow-tools Write Bash(git:*)" "--runs 1" "--model sonnet"; do
  check "options: the head run gets $option" contains "$(calls_in "$repo")" "$option"
  check "options: the base run gets $option" contains "$(calls_outside "$repo")" "$option"
done
check "options: a commit given by its hash is named once" contains "$out" "base: $(sha "$repo" main~1)"$'\n'
check "options: the tools that both runs were granted follow the commits" contains "$out" "head: $(sha "$repo" main)
granted tools: Write, Bash(git:*)

case "

repo=$(two_commits)
result 0.125 "$(case_of plugins/one/evals/red-then-green 0.5 2)" >"$repo/canned-result.json"
echo "# Draft" >"$repo/draft.md"
compare "$repo" main~1
check "uncommitted changes: head is the working tree as it stands" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   0.50 (2 runs)"
check "uncommitted changes: the head line says so" contains "$out" "head: $(sha "$repo" main) with uncommitted changes"
check "uncommitted changes: the working tree is as it was" equals "$(git -C "$repo" status --porcelain)" " M canned-result.json
?? draft.md"

# A run has no gated tool that it does not grant, whatever the case lists, and
# the harness says so about a case that lists one. A grader that expects that
# something did not happen then passes whatever the skill does, so the full
# score of red-then-green at head is no proof. At the base commit the run said
# nothing about a case.
not_granted="not granted (missing --allow-tools grant, or a malformed entry)"
repo=$(two_commits)
{
  progress_of red-then-green "$not_granted: Write"
  progress_of stays-green "$not_granted: Write, Bash"
  progress_of new-at-head
} >"$repo/canned-progress"
commit "$repo" "chore: two cases list gated tools"
compare "$repo" main~1
check "a run that lacked a tool: exits 0" equals "$code" 0
check "a run that lacked a tool: what the harness said is counted beside the score" contains "$out" "plugins/one/evals/red-then-green  1.00 (1 run)   1.00 (1 run, 1 note)"
check "a run that lacked a tool: the case, the commit and the tool follow the table, ahead of the graders" contains "$out" "

plugins/one/evals/red-then-green at head: $not_granted: Write
plugins/one/evals/stays-green at base: grader names-it failed in 2 of 3 runs
plugins/one/evals/stays-green at base: grader asks-first failed in 1 of 3 runs
plugins/one/evals/stays-green at head: $not_granted: Write, Bash
plugins/one/evals/stays-green at head: grader names-it failed in 2 of 3 runs
plugins/one/evals/stays-green at head: grader asks-first failed in 1 of 3 runs

cost:"

# The other way round: at head no case lists a gated tool any more.
progress_of red-then-green >"$repo/canned-progress"
commit "$repo" "chore: no case lists a gated tool"
compare "$repo" main~1
check "a tool that only the base run lacked: is named at base" contains "$out" "
plugins/one/evals/red-then-green at base: $not_granted: Write
"
check "a tool that only the base run lacked: is not named at head" lacks "$out" "at head: not granted"

# The program reads none of the harness's words. Whatever the harness says
# about a case as a whole is repeated as it stands.
repo=$(two_commits)
progress_of new-at-head "$not_granted: Artifact" \
  "the Artifact tool is not available inside eval runs; --allow-tools cannot enable it" >"$repo/canned-progress"
commit "$repo" "chore: a case lists a tool that no grant enables"
compare "$repo" main~1
check "a line in other words: is repeated as it stands" contains "$out" "
plugins/two/evals/new-at-head at head: $not_granted: Artifact
plugins/two/evals/new-at-head at head: the Artifact tool is not available inside eval runs; --allow-tools cannot enable it
"
check "a line in other words: is counted like the other" contains "$out" "plugins/two/evals/new-at-head     1.00 (1 run)   1.00 (1 run, 2 notes)"

# A filter that matches no case at a commit is not a run that died: the
# harness says so, and writes no result.
repo=$(two_commits)
result 0 >"$repo/canned-result.json"
commit "$repo" "chore: a commit without the case"
git -C "$repo" tag without-the-case
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" >"$repo/canned-result.json"
commit "$repo" "chore: the case"
compare "$repo" without-the-case --case 'new-*'
check "no case at the base commit: exits 0" equals "$code" 0
check "no case at the base commit: the case has a dash there" contains "$out" "plugins/two/evals/new-at-head  -     1.00 (1 run)"
check "no case at the base commit: the base run cost nothing" contains "$out" "cost: base 0.00 USD, head 0.50 USD"
check "no case at the base commit: nothing is left behind" nothing_left "$repo"

# A run error is the harness's word for a run it refused or cut short. Three
# runs of one case ended in two of them here, for the same reason.
refusal="the Bash sandbox cannot reliably exclude it"
repo=$(two_commits)
needs_bash=$(case_of plugins/one/evals/needs-bash 0.3333333333333333 3 "$refusal" | jq '.arms.with[0].error = null')
result 0 "$needs_bash" "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
commit "$repo" "chore: a case with run errors"
compare "$repo" base
check "run errors: exits 0" equals "$code" 0
check "run errors: are counted beside the score" contains "$out" "plugins/one/evals/needs-bash       -              0.33 (3 runs, 2 errors)"
check "run errors: a case without one is unmarked" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)"
check "run errors: the reason follows the table, once" equals "$(grep -c -F -- "$refusal" <<<"$out")" 1
check "run errors: the reason names its case and commit" contains "$out" "
plugins/one/evals/needs-bash at head: run error: $refusal
"
check "run errors: the harness says that it kept the sandbox of such a run" contains "$err" "  kept temp (run failed): "
check "run errors: that sandbox is removed too" nothing_left "$repo"
progress_of needs-bash "$not_granted: Bash" >"$repo/canned-progress"
commit "$repo" "chore: the harness says that the case lacked a tool"
compare "$repo" base
check "run errors beside a note: both are counted, the note first" contains "$out" "plugins/one/evals/needs-bash       -              0.33 (3 runs, 1 note, 2 errors)"

repo=$(two_commits)
result 0 "$(case_of plugins/one/evals/red-then-green 0 1 "run hit the turn cap")" >"$repo/canned-result.json"
commit "$repo" "chore: a case with one run error"
compare "$repo" base
check "one run error: is counted in the singular" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   0.00 (1 run, 1 error)"

repo=$(two_commits)
echo 1 >"$repo/canned-exit"
commit "$repo" "chore: a suite with a case below the threshold"
compare "$repo" base
check "a suite below the threshold: still prints the table" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)"
check "a suite below the threshold: exits 0" equals "$code" 0

repo=$(two_commits)
git -C "$repo" rm -q canned-result.json
commit "$repo" "chore: a head whose run dies"
compare "$repo" base
check "no result at head: exits 1" equals "$code" 1
check "no result at head: says which run and how it ended" contains "$err" "compare-evals: the eval run at head wrote no result (claude exited with status 1)"
check "no result at head: prints no table" equals "$out" ""
check "no result at head: nothing is left behind" nothing_left "$repo"

# An interrupt ends the run as well. The run here never ends by itself, and
# the signal reaches the program alone. A command that a script starts in the
# background ignores the signal, so env gives it back its default.
repo=$(two_commits)
: >"$repo/canned-hang"
commit "$repo" "chore: a run that never ends"
remove "$tmp/scratch" && mkdir "$tmp/scratch"
(cd "$repo" && TMPDIR=$tmp/scratch PATH=$path exec env --default-signal=INT "$program" main >/dev/null 2>&1 </dev/null) &
program_pid=$!
for _ in {1..100}; do
  [[ ! -s $FAKE_CLAUDE_PID ]] || break
  sleep 0.1
done
check "an interrupt: comes while the run is on" test -s "$FAKE_CLAUDE_PID"
run_pid=$(<"$FAKE_CLAUDE_PID")
kill -INT "$program_pid"
code=0
wait "$program_pid" || code=$?
check "an interrupt: ends the program the way a signal does" equals "$code" 130
check "an interrupt: ends the run" gone "$run_pid"
check "an interrupt: nothing is left behind" nothing_left "$repo"
kill "$run_pid" 2>/dev/null || true

repo=$(two_commits)
echo '{"schemaVersion": 2, "suites": []}' >"$repo/canned-result.json"
commit "$repo" "chore: a result of another shape"
compare "$repo" base
check "a result of another shape: exits 1" equals "$code" 1
check "a result of another shape: says what is missing" contains "$err" "compare-evals: the result at head has no list 'cases' (schemaVersion 2)"

repo=$(two_commits)
echo '[]' >"$repo/canned-result.json"
commit "$repo" "chore: a result that is a list"
compare "$repo" base
check "a result that is no object: exits 1" equals "$code" 1
check "a result that is no object: says so" contains "$err" "compare-evals: the result at head is not a JSON object"

repo=$(two_commits)
echo 'Usage: claude plugin eval' >"$repo/canned-result.json"
commit "$repo" "chore: a result that is not JSON"
compare "$repo" base
check "a result that is not JSON: exits 1" equals "$code" 1
check "a result that is not JSON: says so" contains "$err" "compare-evals: the result at head is not JSON"

repo=$(two_commits)
result 0.5 '{"dir": "plugins/one/evals/red-then-green", "arms": {"with": []}}' >"$repo/canned-result.json"
commit "$repo" "chore: a case without a score"
compare "$repo" base
check "a case without a score: exits 1" equals "$code" 1
check "a case without a score: names the field" contains "$err" "compare-evals: the result at head holds a field this program cannot read: KeyError('aggregates')"

repo=$(two_commits)
result 0 >"$repo/canned-result.json"
commit "$repo" "chore: no case at head"
compare "$repo" main --case 'no-such-case'
check "no case at either commit: exits 1" equals "$code" 1
check "no case at either commit: says so" contains "$err" "compare-evals: no eval case ran at either commit"

repo=$(two_commits)
git -C "$repo" tag -a -m "the first release" release base
compare "$repo" release
check "a base given as an annotated tag: is named by its commit" contains "$out" "base: $(sha "$repo" base) (release)"$'\n'

repo=$(two_commits)
compare "$repo" main:canned-result.json
check "a base that names a file: exits 1" equals "$code" 1
check "a base that names a file: says so" contains "$err" "compare-evals: 'main:canned-result.json' names no commit"
check "a base that names a file: runs nothing" equals "$calls" ""

repo=$(two_commits)
compare "$repo" no-such-branch
check "a base that names no commit: exits 1" equals "$code" 1
check "a base that names no commit: says so" contains "$err" "compare-evals: 'no-such-branch' names no commit"
check "a base that names no commit: runs nothing" equals "$calls" ""
check "a base that names no commit: nothing is left behind" nothing_left "$repo"

# git gets the base as a revision, never as an option, and the base run gets
# the commit that the base names. Only `git update-ref` makes a branch whose
# name starts with a dash, and only after `--` is such a name the base.
repo=$(two_commits)
git -C "$repo" update-ref refs/heads/--force base
compare "$repo" -- --force
check "a base that starts with a dash: names its commit" contains "$out" "base: $(sha "$repo" base) (--force)"$'\n'
check "a base that starts with a dash: is what the base run checks out" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)"

repo=$(two_commits)
compare "$repo"
check "no base: is a usage error" equals "$code" 2
check "no base: runs nothing" equals "$calls" ""

# The list of tools takes every word after it, the base included.
repo=$(two_commits)
compare "$repo" --allow-tools Write main~1
check "a base after the list of tools: is a usage error" equals "$code" 2
check "a base after the list of tools: the usage line puts the base first" contains "$err" "usage: compare-evals base ["
check "a base after the list of tools: runs nothing" equals "$calls" ""

# Only the options of the usage line reach the harness, so none can move the
# result that the program reads or publish the report.
repo=$(two_commits)
for option in --output-dir --json --report --publish-report; do
  compare "$repo" main~1 "$option" "$tmp/elsewhere"
  check "an option of the harness, $option: is a usage error" equals "$code" 2
  check "an option of the harness, $option: runs nothing" equals "$calls" ""
done

# A value reaches the harness as a word of its own, and one that starts with a
# dash could be an option to it. No case, model, tool or number of runs starts
# with one.
repo=$(two_commits)
for argument in --case=--publish-report --allow-tools=--publish-report --model=--output-dir=/elsewhere --runs=-1; do
  compare "$repo" main~1 "$argument"
  check "a value that starts with a dash, $argument: is a usage error" equals "$code" 2
  check "a value that starts with a dash, $argument: says so" \
    contains "$err" "compare-evals: error: argument ${argument%%=*}: a value cannot start with a dash: '${argument#*=}'"
  check "a value that starts with a dash, $argument: runs nothing" equals "$calls" ""
done

# argparse refuses most such values after a space, and takes one that looks
# like a negative number.
compare "$repo" main~1 --case -1
check "a negative number after a space: is a usage error" equals "$code" 2
check "a negative number after a space: runs nothing" equals "$calls" ""

path=$without_claude
repo=$(two_commits)
compare "$repo" main~1
check "claude is not on the PATH: exits 1" equals "$code" 1
check "claude is not on the PATH: says so" contains "$err" "compare-evals: claude is not on the PATH"
check "claude is not on the PATH: nothing is left behind" nothing_left "$repo"
path=$with_claude

compare "$tmp/empty" main
check "outside a repository: exits 1" equals "$code" 1
check "outside a repository: says so" contains "$err" "compare-evals: not inside a git repository"

if ((failures > 0)); then
  echo "test-compare-evals: $failures failure(s)" >&2
  exit 1
fi
echo "test-compare-evals: ok"
