#!/usr/bin/env bash
# Exercise compare-evals.py against throwaway git repositories, with a stub in
# place of Claude Code, so that no test calls a model. The stub answers
# `claude plugin eval` with the file canned-result.json of the checkout it
# runs in, which differs between the two commits of a fixture. Run through
# `devenv test`.
set -euo pipefail

program=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/compare-evals.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

# --- The stub ----------------------------------------------------------------

# Like the real command, the stub writes its report below the directory it
# runs in unless --output-dir names another, and exits with the status the
# checkout asks for after it wrote the result. A checkout without a canned
# result stands for a run that dies before it writes one.
mkdir "$tmp/bin" "$tmp/tools" "$tmp/empty"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$PWD" "$*" >>"$FAKE_CLAUDE_LOG"
json="" output=evals/results/stub
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
  esac
  shift
done
echo "stub: progress of the run"
[[ -f canned-result.json ]] || exit 1
mkdir -p "$output"
echo "<html></html>" >"$output/report.html"
cp canned-result.json "$json"
[[ ! -f canned-exit ]] || exit "$(<canned-exit)"
EOF
chmod +x "$tmp/bin/claude"
export FAKE_CLAUDE_LOG=$tmp/claude.log

# The program and the stub run with these tools and no others, so that no test
# can reach the real Claude Code, whatever the PATH of the shell that runs it.
for tool in bash cp git mkdir python3; do
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
# score drops over three runs, and one that exists only at the second. The
# tag `base` names the first commit.
two_commits() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q -b main
  result 0.25 \
    "$(case_of plugins/one/evals/red-then-green 0 1)" \
    "$(case_of plugins/one/evals/removed-at-head 1 1)" \
    "$(case_of plugins/one/evals/stays-green 1 3)" >"$repo/canned-result.json"
  commit "$repo" "chore: base"
  git -C "$repo" tag base
  result 0.5 \
    "$(case_of plugins/two/evals/new-at-head 1 1)" \
    "$(case_of plugins/one/evals/stays-green 0.6666666666666666 3)" \
    "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
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

contains() {
  grep -qF -- "$2" <<<"$1" || {
    echo "  missing: $2"
    echo "  in:      ${1//$'\n'/$'\n'           }"
    return 1
  }
}

lacks() {
  ! grep -qF -- "$2" <<<"$1" || {
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
  rm -rf "$tmp/scratch" && mkdir "$tmp/scratch"
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
check "two commits: prints each case with its score and runs at base and at head" equals "$out" "base: $(sha "$repo" main~1) (main~1)
head: $(sha "$repo" main)

case                               base           head
plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)
plugins/one/evals/removed-at-head  1.00 (1 run)   -
plugins/one/evals/stays-green      1.00 (3 runs)  0.67 (3 runs)
plugins/two/evals/new-at-head      -              1.00 (1 run)

cost: base 0.25 USD, head 0.50 USD"
check "two commits: the run's own output stays off stdout" contains "$err" "stub: progress of the run"
check "two commits: one run at head, in the working tree" equals "$(calls_in "$repo" | wc -l)" 1
check "two commits: one run at base, outside the working tree" equals "$(calls_outside "$repo" | wc -l)" 1
check "two commits: the head run is the suite of the checkout, unpublished, without a baseline arm" \
  contains "$(calls_in "$repo")" "plugin eval . "
for flag in "--no-publish" "--ablation none" "--trust-plugin"; do
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

refusal="the Bash sandbox cannot reliably exclude it"
repo=$(two_commits)
result 0 "$(case_of plugins/one/evals/needs-bash 0 1 "$refusal")" "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
commit "$repo" "chore: a case the harness refuses"
compare "$repo" base
check "a refused run: exits 0" equals "$code" 0
check "a refused run: is an error, not a score" contains "$out" "plugins/one/evals/needs-bash       -              error"
check "a refused run: its reason follows the table" contains "$out" "
plugins/one/evals/needs-bash at head: $refusal
"

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
compare "$repo" no-such-branch
check "a base that names no commit: exits 1" equals "$code" 1
check "a base that names no commit: says so" contains "$err" "compare-evals: 'no-such-branch' names no commit"
check "a base that names no commit: runs nothing" equals "$calls" ""
check "a base that names no commit: nothing is left behind" nothing_left "$repo"

repo=$(two_commits)
compare "$repo"
check "no base: is a usage error" equals "$code" 2
check "no base: runs nothing" equals "$calls" ""

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
