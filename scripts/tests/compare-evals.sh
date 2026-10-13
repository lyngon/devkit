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
# after it wrote the result. It prints its progress on stderr and a table on
# stdout, unless --json names a file: then it writes the result there too and
# prints neither. A checkout without a canned result stands for a run that
# dies before it writes one. A canned result without a case stands for a
# filter that matches none: the stub says so and writes a result only where
# --json names a file.
#
# The file canned-listed-tools.json of a checkout maps the name of a case to
# the gated tools it lists. The progress names the ones that --allow-tools
# does not grant, and says of Artifact that no grant enables it. A run that
# ended in an error leaves its sandbox in the temporary directory, read-only,
# unless --json names a file.
mkdir "$tmp/bin" "$tmp/tools" "$tmp/empty"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$PWD" "$*" >>"$FAKE_CLAUDE_LOG"
json="" output=evals/results/stub granted=()
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
    --allow-tools)
      while (($# > 1)) && [[ $2 != --* ]]; do
        granted+=("$2")
        shift
      done
      ;;
  esac
  shift
done
[[ -f canned-result.json ]] || exit 1
if jq -e '.cases == []' canned-result.json >/dev/null 2>&1; then
  echo "No eval cases found under $PWD." >&2
  [[ -z $json ]] || cp canned-result.json "$json"
  exit 1
fi
if [[ -z $json ]]; then
  listed='{}'
  [[ ! -f canned-listed-tools.json ]] || listed=$(<canned-listed-tools.json)
  # A canned result of another shape than the real one has no progress.
  jq -r --argjson listed "$listed" '
    .cases[]? | select(.name) | .name as $name
    | (($listed[$name] // []) - $ARGS.positional) as $denied
    | (select($denied != []) | "  \($name): not granted (missing --allow-tools grant, or a malformed entry): \($denied | join(", "))"),
      (select($denied | any(. == "Artifact")) | "  \($name): the Artifact tool is not available inside eval runs; --allow-tools cannot enable it"),
      (.arms.with | length as $runs | to_entries[] | "  \($name) run \(.key + 1)/\($runs): score \(.value.score)")
  ' canned-result.json --args "${granted[@]}" >&2 2>/dev/null || true
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
export FAKE_CLAUDE_LOG=$tmp/claude.log

# The program and the stub run with these tools and no others, so that no test
# can reach the real Claude Code, whatever the PATH of the shell that runs it.
for tool in bash chmod cp git jq mkdir mktemp python3; do
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

commit() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

# A repository of two commits, each with its own canned result: a case that
# goes from red to green, one that exists only at the first commit, one whose
# score drops over three runs as its graders start to fail, and one that
# exists only at the second. The tag `base` names the first commit.
two_commits() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q -b main
  result 0.25 \
    "$(case_of plugins/one/evals/red-then-green 0 1 | with_grader writes-the-file f)" \
    "$(case_of plugins/one/evals/removed-at-head 1 1 | with_grader writes-the-file p)" \
    "$(case_of plugins/one/evals/stays-green 1 3 | with_grader names-it ppp | with_grader asks-first ppp)" >"$repo/canned-result.json"
  commit "$repo" "chore: base"
  git -C "$repo" tag base
  result 0.5 \
    "$(case_of plugins/two/evals/new-at-head 1 1 | with_grader writes-the-file p)" \
    "$(case_of plugins/one/evals/stays-green 0.6666666666666666 3 | with_grader names-it pff | with_grader asks-first fpp)" \
    "$(case_of plugins/one/evals/red-then-green 1 1 | with_grader writes-the-file p)" >"$repo/canned-result.json"
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
  stays-green run 3/3: score 0
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

repo=$(two_commits)
result 0.125 "$(case_of plugins/one/evals/red-then-green 0.5 2)" >"$repo/canned-result.json"
echo "# Draft" >"$repo/draft.md"
compare "$repo" main~1
check "uncommitted changes: head is the working tree as it stands" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   0.50 (2 runs)"
check "uncommitted changes: the head line says so" contains "$out" "head: $(sha "$repo" main) with uncommitted changes"
check "uncommitted changes: the working tree is as it was" equals "$(git -C "$repo" status --porcelain)" " M canned-result.json
?? draft.md"

# A run has no gated tool that it does not grant, whatever the case lists. A
# grader that expects that something did not happen then passes whatever the
# skill does, so the full score of red-then-green at head is no proof. The
# base commit has no case that lists a gated tool.
repo=$(two_commits)
echo '{"red-then-green": ["Write"], "stays-green": ["Write", "Bash"]}' >"$repo/canned-listed-tools.json"
commit "$repo" "chore: two cases list gated tools"
compare "$repo" main~1
check "a run that lacked a tool: exits 0" equals "$code" 0
check "a run that lacked a tool: the case has its score" contains "$out" "plugins/one/evals/red-then-green  1.00 (1 run)   1.00 (1 run)"
check "a run that lacked a tool: the case, the commit and the tool follow the table, ahead of the graders" contains "$out" "

plugins/one/evals/red-then-green at head: not granted (missing --allow-tools grant, or a malformed entry): Write
plugins/one/evals/stays-green at base: grader names-it failed in 2 of 3 runs
plugins/one/evals/stays-green at base: grader asks-first failed in 1 of 3 runs
plugins/one/evals/stays-green at head: not granted (missing --allow-tools grant, or a malformed entry): Write, Bash
plugins/one/evals/stays-green at head: grader names-it failed in 2 of 3 runs
plugins/one/evals/stays-green at head: grader asks-first failed in 1 of 3 runs

cost:"
compare "$repo" main~1 --allow-tools Write
check "a grant: a case that has every tool it lists is not named" lacks "$out" "red-then-green at head"
check "a grant: a tool that is still missing is named" contains "$out" "
plugins/one/evals/stays-green at head: not granted (missing --allow-tools grant, or a malformed entry): Bash
"

# The program reads none of the harness's words. Whatever the harness says
# about a case as a whole is repeated as it stands.
repo=$(two_commits)
echo '{"new-at-head": ["Artifact"]}' >"$repo/canned-listed-tools.json"
commit "$repo" "chore: a case lists a tool that no grant enables"
compare "$repo" main~1
check "a line in other words: is repeated as it stands" contains "$out" "
plugins/two/evals/new-at-head at head: not granted (missing --allow-tools grant, or a malformed entry): Artifact
plugins/two/evals/new-at-head at head: the Artifact tool is not available inside eval runs; --allow-tools cannot enable it
"

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
