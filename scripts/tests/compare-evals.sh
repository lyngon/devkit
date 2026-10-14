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
# The checks read the usage line of argparse as plain text, which Python 3.14
# colors under FORCE_COLOR or PYTHON_COLORS=1. PYTHON_COLORS=0 wins over both.
export PYTHON_COLORS=0
failures=0

# --- The stub ----------------------------------------------------------------

# The stub does what the real command was measured to do on Claude Code
# 2.1.283. It writes aggregate-result.json and its report into the directory
# that --output-dir names, and exits with the status the checkout asks for
# after it wrote the result. It prints the file canned-progress of the
# checkout on stderr and a table on stdout, unless --json names a file: then
# it writes the result there too and prints neither. Where the progress says
# <checkout>, the stub prints the path of the directory it runs in, without
# symbolic links, as the harness names a case by such a path. A run that
# ended in an error leaves its sandbox in the temporary directory, read-only,
# unless --json names a file.
#
# A checkout without a canned result stands for a run that writes none: the
# stub prints the canned progress and the file canned-stdout of the checkout,
# where it has them and --json names no file, and exits with the status the
# checkout asks for, 1 where it asks for none. A canned result without a case
# stands for a filter that matches none: the stub says so and writes a result
# only where --json names a file.
# So no canned result can stand for a partial result without a case, which
# the harness was not measured to treat like that filter.
# A checkout with the file canned-hang stands for a run that never ends: the
# stub writes its process ID to the file that FAKE_CLAUDE_PID names and stays.
# The stub also writes to the file that FAKE_BUILD_LOG names what the command
# check-pull-request that it finds says, or `none`, which tells the build of
# the environment that it runs in.
mkdir "$tmp/bin" "$tmp/devenv" "$tmp/tools" "$tmp/empty" "$tmp/store"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$PWD" "$*" >>"$FAKE_CLAUDE_LOG"
printf '%s\t%s\n' "$PWD" "$(check-pull-request 2>/dev/null || echo none)" >>"$FAKE_BUILD_LOG"
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
print_progress() {
  [[ -f canned-progress ]] || return 0
  local progress
  progress=$(<canned-progress)
  echo "${progress//<checkout>/"$(pwd -P)"}" >&2
}
if [[ ! -f canned-result.json ]]; then
  if [[ -z $json ]]; then
    print_progress
    [[ ! -f canned-stdout ]] || echo "$(<canned-stdout)"
  fi
  [[ ! -f canned-exit ]] || exit "$(<canned-exit)"
  exit 1
fi
if jq -e '.cases == []' canned-result.json >/dev/null 2>&1; then
  echo "No eval cases found$filter under $PWD." >&2
  [[ -z $json ]] || cp canned-result.json "$json"
  exit 1
fi
if [[ -z $json ]]; then
  print_progress
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
export FAKE_CLAUDE_LOG=$tmp/claude.log FAKE_CLAUDE_PID=$tmp/claude.pid FAKE_BUILD_LOG=$tmp/build.log
export FAKE_TASK_PID=$tmp/task.pid

# The stub of devenv does what `devenv shell -- <command>` of devenv 2.4.0 was
# measured to do in a checkout: it writes the git hook shims of the checkout's
# environment into the hooks directory that git names there, prints the tasks
# it runs on stderr, in lines copied from a real run, puts that environment in
# front of the PATH and replaces itself with the command. The shim is the file
# canned-shim of the checkout, copied from one that devenv wrote, with the path
# of the checkout without symbolic links in place of <checkout>. The
# environment is the directory baseline of the checkout. A checkout with the
# file canned-devenv-exit stands for an environment that does not build, and
# one with the file canned-devenv-hang for a task that never ends: the stub
# starts it, writes its own process ID to the file that FAKE_CLAUDE_PID names
# and the task's to the one that FAKE_TASK_PID names, and waits.
cat >"$tmp/devenv/devenv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -gt 2 && $1 == shell && $2 == -- ]] || exit 2
shift 2
if [[ -f canned-shim ]]; then
  shim=$(<canned-shim)
  echo "${shim//<checkout>/"$(pwd -P)"}" >"$(git rev-parse --path-format=absolute --git-path hooks)/pre-commit"
fi
if [[ -f canned-devenv-hang ]]; then
  sleep 1000 &
  echo "$!" >"$FAKE_TASK_PID"
  echo "$$" >"$FAKE_CLAUDE_PID"
  wait
fi
[[ ! -f canned-devenv-exit ]] || exit "$(<canned-devenv-exit)"
echo "• Running devenv:files:cleanup
✓ Running devenv:files:cleanup in 32.2ms
• Running devenv:files
✓ Running devenv:files in 39.5ms
• Running devenv:git-hooks:install
✓ Running devenv:git-hooks:install in 61.8ms
• Running lyngon:git-hooks:refresh-unused-shims
✓ Running lyngon:git-hooks:refresh-unused-shims in 29.7ms
• Running devenv:enterShell
✓ Running devenv:enterShell in 35.7ms" >&2
PATH=$PWD/baseline:$PATH exec "$@"
EOF
chmod +x "$tmp/devenv/devenv"

# The program and the stubs run with these tools and no others, so that no
# test can reach the real Claude Code or devenv, whatever the PATH of the shell
# that runs it.
for tool in bash chmod cp env git jq mkdir mktemp python3 sleep; do
  ln -s "$(command -v "$tool")" "$tmp/tools/$tool"
done
with_claude=$tmp/bin:$tmp/devenv:$tmp/tools
without_claude=$tmp/tools
without_devenv=$tmp/bin:$tmp/tools
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

# cut_short <reason>: the result on stdin as the harness writes it for a suite
# that it ended before every run started, with its reason. The two fields are
# the ones that the documentation of the harness names; no run here produced
# such a result.
cut_short() {
  jq --arg reason "$1" '.partial = true | .partialReason = $reason'
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

# failed_to_load <path> <error>: what the real command prints on stderr for a
# case whose file it failed to load, copied from a run on Claude Code 2.1.283.
# It names the case by the absolute path of its directory, or of its
# case.yaml where it has one, and leaves the case out of its result. The stub
# puts the checkout in place of <checkout>. These are two of its errors.
failed_to_load() {
  echo "✗ <checkout>/$1: $2"
}
invalid_yaml="prompt.md: invalid YAML frontmatter: YAML Parse error: Unexpected token"
no_graders="invalid case.yaml:   graders: Required"

# no_case_ran: what the real command prints on stdout when a case file failed
# to load and no case that the filter matches loads, copied from a run on
# Claude Code 2.1.283: an empty table and its summary. It writes no result
# then, exits with status 1 and does not say `No eval cases found`. A last
# line, which counts the files that failed to load, is left out.
no_case_ran() {
  cat <<'EOF'

CASE  SCORE PASS% RUNS COST    NOTES

0 case(s) · 0s · $0.00
EOF
}

# commit <repo> <message> [<case>...]: commit the fixture as it stands. The
# commit has the cases that its canned result names and the cases named here,
# which its run gives no result for. A case is a directory with a prompt.md,
# as in a real checkout.
commit() {
  local repo=$1 message=$2 dir
  shift 2
  rm -rf "$repo/plugins"
  {
    printf '%s\n' "$@"
    jq -r '.cases[]?.dir // empty' "$repo/canned-result.json" 2>/dev/null || true
  } | while IFS= read -r dir; do
    [[ -n $dir ]] || continue
    mkdir -p "$repo/$dir"
    echo "A case of the fixture." >"$repo/$dir/prompt.md"
  done
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$message"
}

# A repository of two commits, each with its own canned result: a case that
# goes from red to green, one that exists only at the first commit, one whose
# score drops over three runs as its graders start to fail, and one that
# exists only at the second. Each commit has the cases that its result names.
# Neither run says anything about a case as a whole. The tag `base` names the
# first commit.
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
# stdout, stderr and the exit code in out, err and code, the stub's calls in
# calls and the builds that its runs found in builds. Temporary files go to an
# empty directory of their own, which the program finds where temporary says.
# The shell that starts the program is the devenv shell of the repository,
# unless shell_root names another directory, and its Nix store is $tmp/store.
temporary=$tmp/scratch
shell_root=""
compare() {
  local repo=$1 root
  shift
  root=${shell_root:-$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || echo "$repo")}
  remove "$tmp/scratch" && mkdir "$tmp/scratch"
  : >"$FAKE_CLAUDE_LOG"
  : >"$FAKE_BUILD_LOG"
  code=0
  out=$(cd "$repo" && TMPDIR=$temporary NIX_STORE=$tmp/store DEVENV_ROOT=$root PATH=$path "$program" "$@" \
    2>"$tmp/stderr" </dev/null) || code=$?
  err=$(<"$tmp/stderr")
  calls=$(<"$FAKE_CLAUDE_LOG")
  builds=$(<"$FAKE_BUILD_LOG")
}

# The stub's calls from inside the repository, and from outside it.
calls_in() {
  grep -F -- "$1"$'\t' <<<"$calls" || true
}

calls_outside() {
  grep -vF -- "$1"$'\t' <<<"$calls" || true
}

# The build that the run inside the repository found, and the one that the
# run outside it found.
build_in() {
  grep -F -- "$1"$'\t' <<<"$builds" | cut -f 2
}

build_outside() {
  grep -vF -- "$1"$'\t' <<<"$builds" | cut -f 2
}

# hooks <repo>: the git hooks of the repository, each with its content.
hooks() {
  local hook
  for hook in "$1"/.git/hooks/*; do
    printf '%s %s\n' "$(basename "$hook")" "$(sha256sum <"$hook" | cut -c 1-16)"
  done
}

# shim_of <config>: a git hook shim as devenv 2.4.0 writes it, copied from one
# that it wrote, with the configuration that it names. Before 7e4605f the
# baseline had it name the configuration by an absolute path, which here says
# <checkout>.
shim_of() {
  cat <<EOF
#!/bin/sh
# File generated by prek: https://github.com/j178/prek
# ID: 182c10f181da4464a3eec51b83331688

HERE="\$(cd "\$(dirname "\$0")" && pwd)"
PREK="/nix/store/n7cq6kxkq64jgm1bs952ibl64l0181x1-prek-0.4.14/bin/prek"

# Check if the full path to prek is executable, otherwise fallback to PATH
if [ ! -x "\$PREK" ]; then
    PREK="prek"
fi

exec "\$PREK" hook-impl --hook-dir "\$HERE" --script-version 4 --hook-type=pre-commit --config="$1" -- "\$@"
EOF
}

# with_build <repo> <words>: the commit in the repository gets an environment
# whose check-pull-request says the words.
with_build() {
  mkdir -p "$1/baseline"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$2" >"$1/baseline/check-pull-request"
  chmod +x "$1/baseline/check-pull-request"
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

# Each --allow-tools adds its list to the grant. A second one that took the
# place of the first would leave a run without a tool that the operator named.
repo=$(two_commits)
compare "$repo" main~1 --allow-tools Write --case 'red-*' --allow-tools 'Bash(git:*)' Edit
check "a second list of tools: the head run gets both lists" contains "$(calls_in "$repo")" "--allow-tools Write Bash(git:*) Edit"
check "a second list of tools: the base run gets both lists" contains "$(calls_outside "$repo")" "--allow-tools Write Bash(git:*) Edit"
check "a second list of tools: the comparison names every tool" contains "$out" "
granted tools: Write, Bash(git:*), Edit
"

# The working tree here gives another score for one case and has lost the
# prompt.md of another case, which keeps only a workspace, and none of it is
# committed.
repo=$(two_commits)
result 0.125 "$(case_of plugins/two/evals/new-at-head 1 1)" "$(case_of plugins/one/evals/red-then-green 0.5 2)" >"$repo/canned-result.json"
rm -r "$repo/plugins/one/evals/stays-green"
mkdir -p "$repo/plugins/one/evals/stays-green/workspace"
echo "A file that a later case reads." >"$repo/plugins/one/evals/stays-green/workspace/notes.md"
echo "# Draft" >"$repo/draft.md"
compare "$repo" main~1
check "uncommitted changes: head is the working tree as it stands" contains "$out" "plugins/one/evals/red-then-green   0.00 (1 run)   0.50 (2 runs)"
check "uncommitted changes: a case that the working tree lost has a dash at head" contains "$out" "
plugins/one/evals/stays-green      1.00 (3 runs)  -
"
check "uncommitted changes: the head line says so" contains "$out" "head: $(sha "$repo" main) with uncommitted changes"
check "uncommitted changes: the working tree is as it was" equals "$(git -C "$repo" status --porcelain)" " M canned-result.json
 D plugins/one/evals/stays-green/prompt.md
?? draft.md
?? plugins/one/evals/stays-green/workspace/"

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

# The harness refuses an entry of --allow-tools that it cannot grant, says so
# in a line of its own, and the runs go on without the tool (measured on
# Claude Code 2.1.283). Both runs get the grant, so both refuse it. The header
# names the tools that the operator asked for, so each line follows the table
# with its commit.
refused_grant="--allow-tools: refused entry: malformed, a wildcard tool name the child does not support, or a tool never available in an evaluation (Monitor, EnterWorktree, ExitWorktree): Monitor"
repo=$(two_commits)
echo "✗ $refused_grant" >"$repo/canned-progress"
echo 1 >"$repo/canned-exit"
commit "$repo" "chore: a commit whose run refuses a grant"
git -C "$repo" tag refusing
echo "A change at head." >"$repo/notes.md"
commit "$repo" "chore: a head whose run refuses the grant too"
compare "$repo" refusing --allow-tools Monitor Write
check "a refused grant: exits 0" equals "$code" 0
check "a refused grant: the header names the tools that were asked for" contains "$out" "
granted tools: Monitor, Write
"
check "a refused grant: each line follows the table, with its commit, the base first" contains "$out" "

the eval run at base said $refused_grant
the eval run at head said $refused_grant

"

# A filter that matches no case at a commit is not a run that died: the
# harness says so, and writes no result. The directory of the case is there
# already, with a workspace and without a prompt.md, so it is no case yet.
repo=$(two_commits)
result 0 >"$repo/canned-result.json"
commit "$repo" "chore: a commit without the case"
mkdir -p "$repo/plugins/two/evals/new-at-head/workspace"
echo "A file that a later case reads." >"$repo/plugins/two/evals/new-at-head/workspace/notes.md"
git -C "$repo" add -A
git -C "$repo" commit -q -m "chore: a workspace for a later case"
git -C "$repo" tag without-the-case
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" >"$repo/canned-result.json"
commit "$repo" "chore: the case"
compare "$repo" without-the-case --case 'new-*'
check "no case at the base commit: exits 0" equals "$code" 0
check "no case at the base commit: the case has a dash there" contains "$out" "plugins/two/evals/new-at-head  -     1.00 (1 run)"
check "no case at the base commit: the base run cost nothing" contains "$out" "cost: base 0.00 USD, head 0.50 USD"
check "no case at the base commit: nothing is left behind" nothing_left "$repo"

# Nor is it one when a case file of that commit fails to load. The harness
# then prints an empty table and its summary in place of the words, and
# writes no result. Under --case it names a file whose case the filter leaves
# out, as here at the base commit (measured on Claude Code 2.1.283).
repo=$(two_commits)
rm "$repo/canned-result.json"
failed_to_load plugins/one/evals/stays-green "$invalid_yaml" >"$repo/canned-progress"
no_case_ran >"$repo/canned-stdout"
commit "$repo" "chore: a commit without the case and with a file that fails to load" plugins/one/evals/stays-green
git -C "$repo" tag without-the-case
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" >"$repo/canned-result.json"
rm "$repo/canned-progress" "$repo/canned-stdout"
commit "$repo" "chore: the case" plugins/one/evals/stays-green
compare "$repo" without-the-case --case 'new-*'
check "no case at the base commit, and a file that fails to load there: exits 0" equals "$code" 0
check "no case at the base commit, and a file that fails to load there: the case has a dash there, and the file is named" equals "$out" "base: $(sha "$repo" without-the-case) (without-the-case)
head: $(sha "$repo" main)
granted tools: none

case                           base  head
plugins/two/evals/new-at-head  -     1.00 (1 run)

the eval run at base failed to load plugins/one/evals/stays-green: $invalid_yaml

cost: base 0.00 USD, head 0.50 USD"
check "no case at the base commit, and a file that fails to load there: nothing is left behind" nothing_left "$repo"

# When the one case that the filter matches fails to load, no case runs at
# either commit. There is no comparison then, as for a filter that matches
# nothing, and the error names the file that failed to load.
repo=$(two_commits)
result 0 >"$repo/canned-result.json"
commit "$repo" "chore: a commit without the case"
git -C "$repo" tag without-the-case
rm "$repo/canned-result.json"
failed_to_load plugins/two/evals/new-at-head "$invalid_yaml" >"$repo/canned-progress"
no_case_ran >"$repo/canned-stdout"
commit "$repo" "chore: the case, whose file fails to load" plugins/two/evals/new-at-head
compare "$repo" without-the-case --case 'new-*'
check "no case at either commit, and a file that fails to load at head: exits 1" equals "$code" 1
check "no case at either commit, and a file that fails to load at head: prints no table" equals "$out" ""
check "no case at either commit, and a file that fails to load at head: the error names the file" contains "$err" "
compare-evals: no eval case ran at either commit
the eval run at head failed to load plugins/two/evals/new-at-head: $invalid_yaml"
check "no case at either commit, and a file that fails to load at head: nothing is left behind" nothing_left "$repo"

# The likelier case: the file of the case that the filter names fails to load
# at head, after the base run scored it. The base score stays, and the line
# says why head has none.
repo=$(two_commits)
rm "$repo/canned-result.json"
failed_to_load plugins/one/evals/red-then-green "$invalid_yaml" >"$repo/canned-progress"
no_case_ran >"$repo/canned-stdout"
commit "$repo" "chore: the file of the case fails to load" plugins/one/evals/red-then-green
compare "$repo" base --case 'red-*'
check "the file of the filtered case fails to load at head: exits 0" equals "$code" 0
check "the file of the filtered case fails to load at head: the base score stays, beside no result" contains "$out" "
plugins/one/evals/red-then-green   0.00 (1 run)   no result
"
check "the file of the filtered case fails to load at head: the line follows the table" contains "$out" "

the eval run at head failed to load plugins/one/evals/red-then-green: $invalid_yaml

"

# A suite that the harness ends before its first case finished prints the
# same summary, marked partial, writes no result and exits with another
# status: 143 here, where it got SIGTERM (measured on Claude Code 2.1.283).
# That run died.
repo=$(two_commits)
rm "$repo/canned-result.json"
failed_to_load plugins/one/evals/stays-green "$invalid_yaml" >"$repo/canned-progress"
cat >"$repo/canned-stdout" <<'EOF'

CASE  SCORE PASS% RUNS COST    NOTES

0 case(s) · 0s · $0.00 · ⚠ partial (interrupted)
EOF
echo 143 >"$repo/canned-exit"
commit "$repo" "chore: a head whose run is ended before its first case" plugins/one/evals/stays-green
compare "$repo" base
check "a suite ended before its first case: exits 1" equals "$code" 1
check "a suite ended before its first case: is a run that wrote no result" contains "$err" "compare-evals: the eval run at head wrote no result (claude exited with status 143)"

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

# The harness ends a suite before every run started when it is interrupted,
# when its credential is rejected and at a cost ceiling. Its result then says
# that it is partial and why, and lacks each case that did not run. The dash
# is for a case that the commit does not have, so a case that the commit has
# and its run did not reach gets words of its own. Here the head run reached
# two of the three cases of the head commit, and that commit does not have a
# fourth case, which the base run scored.
repo=$(two_commits)
result 0.4 \
  "$(case_of plugins/two/evals/new-at-head 1 1 | with_grader writes-the-file p)" \
  "$(case_of plugins/one/evals/red-then-green 1 1 | with_grader writes-the-file p)" | cut_short interrupted >"$repo/canned-result.json"
echo 130 >"$repo/canned-exit"
commit "$repo" "chore: a head whose run is cut short" plugins/one/evals/stays-green
compare "$repo" base
check "a suite cut short: exits 0" equals "$code" 0
check "a suite cut short: a line below the table names the commit and the harness's reason, and a case that the run did not reach is told from one that the commit does not have" equals "$out" "base: $(sha "$repo" base) (base)
head: $(sha "$repo" main)
granted tools: none

case                               base           head
plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)
plugins/one/evals/removed-at-head  1.00 (1 run)   -
plugins/one/evals/stays-green      1.00 (3 runs)  no result
plugins/two/evals/new-at-head      -              1.00 (1 run)

the eval run at head was cut short (interrupted): the table may lack cases

plugins/one/evals/red-then-green at base: grader writes-the-file failed in 1 of 1 runs

cost: base 0.25 USD, head 0.40 USD"

# Both suites cut short, each for its own reason. The program reads none of the
# reasons, and repeats the harness's word.
repo=$(two_commits)
result 0.1 "$(case_of plugins/one/evals/red-then-green 0 1)" | cut_short cost_ceiling >"$repo/canned-result.json"
echo 2 >"$repo/canned-exit"
commit "$repo" "chore: a commit whose run is cut short" plugins/one/evals/stays-green
git -C "$repo" tag cut-short
result 0.3 "$(case_of plugins/one/evals/red-then-green 1 1)" "$(case_of plugins/one/evals/stays-green 1 3)" |
  cut_short interrupted >"$repo/canned-result.json"
echo 130 >"$repo/canned-exit"
commit "$repo" "chore: a head whose run is cut short too"
compare "$repo" cut-short
check "both suites cut short: each has its line, the base first" contains "$out" "

the eval run at base was cut short (cost_ceiling): the table may lack cases
the eval run at head was cut short (interrupted): the table may lack cases

cost:"
check "both suites cut short: a case that the base commit has and its run did not reach has no dash there" contains "$out" "
plugins/one/evals/stays-green     no result     1.00 (3 runs)
"

# A whole result can lack a case that the commit has too: the harness leaves
# out each case whose file it failed to load, says so on stderr and exits
# with status 1 (measured on Claude Code 2.1.283). Here the file of a case
# that the base run scored fails to load at head, and so does the case.yaml
# of the case that is new at head, which then has a result at neither commit
# and no row.
repo=$(two_commits)
result 0.4 "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
{
  failed_to_load plugins/one/evals/stays-green "$invalid_yaml"
  failed_to_load plugins/two/evals/new-at-head/case.yaml "$no_graders"
} >"$repo/canned-progress"
echo 1 >"$repo/canned-exit"
commit "$repo" "chore: a head with case files that fail to load" \
  plugins/one/evals/stays-green plugins/two/evals/new-at-head
compare "$repo" base
check "case files that failed to load: exits 0" equals "$code" 0
check "case files that failed to load: each line of the harness follows the table with its commit and the case from the root, and a case that the commit has is told from one that it does not have" equals "$out" "base: $(sha "$repo" base) (base)
head: $(sha "$repo" main)
granted tools: none

case                               base           head
plugins/one/evals/red-then-green   0.00 (1 run)   1.00 (1 run)
plugins/one/evals/removed-at-head  1.00 (1 run)   -
plugins/one/evals/stays-green      1.00 (3 runs)  no result

the eval run at head failed to load plugins/one/evals/stays-green: $invalid_yaml
the eval run at head failed to load plugins/two/evals/new-at-head/case.yaml: $no_graders

plugins/one/evals/red-then-green at base: grader writes-the-file failed in 1 of 1 runs

cost: base 0.25 USD, head 0.40 USD"
compare "$repo/plugins" base
check "case files that failed to load: are found from a directory below the root too" contains "$out" "
plugins/one/evals/stays-green      1.00 (3 runs)  no result

the eval run at head failed to load plugins/one/evals/stays-green: $invalid_yaml
"

# At the base commit the harness names a case by its path in the checkout of
# that commit, a temporary directory that is gone when the comparison is
# read. That path has no symbolic link in it, even where the run starts from
# one (measured on Claude Code 2.1.283), and here the temporary directory is
# reached through one.
repo=$(two_commits)
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" >"$repo/canned-result.json"
failed_to_load plugins/one/evals/red-then-green "$invalid_yaml" >"$repo/canned-progress"
echo 1 >"$repo/canned-exit"
commit "$repo" "chore: a commit with a case file that fails to load" plugins/one/evals/red-then-green
git -C "$repo" tag fails-to-load
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
rm "$repo/canned-progress" "$repo/canned-exit"
commit "$repo" "chore: the file loads again"
ln -s scratch "$tmp/scratch-link"
temporary=$tmp/scratch-link
compare "$repo" fails-to-load
temporary=$tmp/scratch
check "a case file that failed to load at the base commit: is named from the root, also behind a symbolic link" contains "$out" "

the eval run at base failed to load plugins/one/evals/red-then-green: $invalid_yaml

cost:"
check "a case file that failed to load at the base commit: nothing is left behind" nothing_left "$repo"

# A suite can fail to load a file and be cut short too. Both lines name its
# commit, in the order the harness met the two: the file before the runs.
repo=$(two_commits)
result 0.4 "$(case_of plugins/one/evals/red-then-green 1 1)" | cut_short interrupted >"$repo/canned-result.json"
failed_to_load plugins/two/evals/new-at-head "$invalid_yaml" >"$repo/canned-progress"
echo 130 >"$repo/canned-exit"
commit "$repo" "chore: a head that fails to load a file and is cut short" plugins/two/evals/new-at-head
compare "$repo" base
check "a case file that failed to load in a suite cut short: comes first" contains "$out" "

the eval run at head failed to load plugins/two/evals/new-at-head: $invalid_yaml
the eval run at head was cut short (interrupted): the table may lack cases

"

# The program looks a case up by the path that a result gives it. A result
# whose path names no case in the working tree has another shape than the one
# the program was written against.
repo=$(two_commits)
result 0.5 "$(case_of one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
compare "$repo" base
check "a path that names no case at head: exits 1" equals "$code" 1
check "a path that names no case at head: names the path" contains "$err" "compare-evals: the result at head names the case one/evals/red-then-green, which holds no prompt.md in the working tree"

# A result that does not say whether it is partial is not taken for a whole
# one.
repo=$(two_commits)
result 0.5 "$(case_of plugins/one/evals/red-then-green 1 1)" | jq 'del(.partial)' >"$repo/canned-result.json"
commit "$repo" "chore: a result that does not say whether it is partial"
compare "$repo" base
check "a result without the field partial: exits 1" equals "$code" 1
check "a result without the field partial: names the field" contains "$err" "compare-evals: the result at head holds a field this program cannot read: KeyError('partial')"

# Nor does a partial result without a reason get a line that names none.
repo=$(two_commits)
result 0.5 "$(case_of plugins/one/evals/red-then-green 1 1)" | jq '.partial = true' >"$repo/canned-result.json"
commit "$repo" "chore: a partial result without a reason"
compare "$repo" base
check "a partial result without a reason: exits 1" equals "$code" 1
check "a partial result without a reason: names the field" contains "$err" "compare-evals: the result at head holds a field this program cannot read: KeyError('partialReason')"

# A run that dies after it named a case file that failed to load, before its
# summary, found a case or not: the line alone does not say.
repo=$(two_commits)
git -C "$repo" rm -q canned-result.json
failed_to_load plugins/two/evals/new-at-head "$invalid_yaml" >"$repo/canned-progress"
commit "$repo" "chore: a head whose run dies"
compare "$repo" base
check "no result at head: exits 1" equals "$code" 1
check "no result at head: says which run and how it ended" contains "$err" "compare-evals: the eval run at head wrote no result (claude exited with status 1)"
check "no result at head: prints what each case scored at the base commit, which was paid for, and what the head run said" equals "$out" "base: $(sha "$repo" base) (base)
head: $(sha "$repo" main)
granted tools: none

case                               base
plugins/one/evals/red-then-green   0.00 (1 run)
plugins/one/evals/removed-at-head  1.00 (1 run)
plugins/one/evals/stays-green      1.00 (3 runs)

the eval run at head failed to load plugins/two/evals/new-at-head: $invalid_yaml
the eval run at head wrote no result (claude exited with status 1)

plugins/one/evals/red-then-green at base: grader writes-the-file failed in 1 of 1 runs

cost: base 0.25 USD"
check "no result at head: nothing is left behind" nothing_left "$repo"

# A head result that the program cannot read is no result either.
repo=$(two_commits)
echo 'Usage: claude plugin eval' >"$repo/canned-result.json"
commit "$repo" "chore: a head whose result is not JSON"
compare "$repo" base
check "an unreadable result at head: exits 1" equals "$code" 1
check "an unreadable result at head: prints the table of the base run, and why there is no other" contains "$out" "
plugins/one/evals/stays-green      1.00 (3 runs)

the result at head is not JSON: "

# When the base run found no case, nothing is left to print, and the error
# names what each run said.
repo=$(two_commits)
rm "$repo/canned-result.json"
failed_to_load plugins/one/evals/stays-green "$invalid_yaml" >"$repo/canned-progress"
no_case_ran >"$repo/canned-stdout"
commit "$repo" "chore: a commit without the case and with a file that fails to load" plugins/one/evals/stays-green
git -C "$repo" tag without-the-case
rm "$repo/canned-stdout"
failed_to_load plugins/two/evals/new-at-head "$invalid_yaml" >"$repo/canned-progress"
commit "$repo" "chore: a head whose run dies" plugins/two/evals/new-at-head
compare "$repo" without-the-case --case 'new-*'
check "no case at base and no result at head: exits 1" equals "$code" 1
check "no case at base and no result at head: prints no table" equals "$out" ""
check "no case at base and no result at head: the error names what each run said" contains "$err" "
compare-evals: the eval run at head wrote no result (claude exited with status 1)
the eval run at base failed to load plugins/one/evals/stays-green: $invalid_yaml
the eval run at head failed to load plugins/two/evals/new-at-head: $invalid_yaml"

# A base run that writes no result ends the comparison before the head run,
# which would cost money for nothing to compare.
repo=$(two_commits)
git -C "$repo" checkout -q base
git -C "$repo" rm -q canned-result.json
failed_to_load plugins/one/evals/stays-green "$invalid_yaml" >"$repo/canned-progress"
commit "$repo" "chore: a base whose run dies" plugins/one/evals/stays-green
git -C "$repo" tag dead-base
git -C "$repo" checkout -q main
compare "$repo" dead-base
check "no result at base: exits 1" equals "$code" 1
check "no result at base: says which run and how it ended, and what it said" contains "$err" "
compare-evals: the eval run at base wrote no result (devenv shell exited with status 1)
the eval run at base failed to load plugins/one/evals/stays-green: $invalid_yaml"
check "no result at base: prints no table" equals "$out" ""
check "no result at base: runs nothing at head" equals "$(calls_in "$repo")" ""

# Each run gets the commands of its own commit. The base run enters the
# environment of the base commit with devenv shell, in its checkout; the head
# run keeps the environment that it was started from, the working tree's,
# whose commands lie in the Nix store. The base run finds none of those, so a
# command that the base commit lacks is missing there, as it was then.
mkdir -p "$tmp/store/working-tree-environment/bin"
printf '#!/usr/bin/env bash\necho "check-pull-request of the working tree"\n' \
  >"$tmp/store/working-tree-environment/bin/check-pull-request"
chmod +x "$tmp/store/working-tree-environment/bin/check-pull-request"
path=$tmp/store/working-tree-environment/bin:$with_claude
repo=$(two_commits)
compare "$repo" base
check "a command that the base commit lacks: is not found at base" equals "$(build_outside "$repo")" none
check "a command that the base commit lacks: is found at head, in the environment of the working tree" \
  equals "$(build_in "$repo")" "check-pull-request of the working tree"
with_build "$repo" "check-pull-request of the base commit"
cat >"$repo/baseline/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\tthe claude of an environment\n' "$PWD" >>"$FAKE_CLAUDE_LOG"
exit 1
EOF
chmod +x "$repo/baseline/claude"
commit "$repo" "chore: a commit with an environment of its own"
git -C "$repo" tag with-build
with_build "$repo" "check-pull-request of the head commit"
commit "$repo" "chore: a head that changes the environment"
compare "$repo" with-build
check "a command that both commits have: the base run gets the base commit's build" \
  equals "$(build_outside "$repo")" "check-pull-request of the base commit"
check "a command that both commits have: the head run gets the working tree's environment" \
  equals "$(build_in "$repo")" "check-pull-request of the working tree"
check "a claude in the environment of the base commit: both runs start the claude that the program found" \
  lacks "$calls" "the claude of an environment"
check "a command that both commits have: nothing is left behind" nothing_left "$repo"
path=$with_claude

# Entering the environment of a commit writes git hook shims. Before 7e4605f
# the baseline had them name its configuration by the absolute path of the
# checkout, which compare-evals removes, so a shim in the hooks of the working
# tree would then fail every commit. The base checkout is a repository of its
# own, and the hooks of the working tree stay as they were, whichever form
# the base writes.
for config in '<checkout>/.pre-commit-config.yaml' './.pre-commit-config.yaml'; do
  repo=$(two_commits)
  shim_of "$config" >"$repo/canned-shim"
  commit "$repo" "chore: a commit whose environment writes a shim"
  git -C "$repo" tag writes-a-shim
  rm "$repo/canned-shim"
  commit "$repo" "chore: a head whose environment the shell entered"
  shim_of ./.pre-commit-config.yaml >"$repo/.git/hooks/pre-commit"
  chmod +x "$repo/.git/hooks/pre-commit"
  found=$(hooks "$repo")
  compare "$repo" writes-a-shim
  check "a base whose environment writes a shim naming $config: exits 0" equals "$code" 0
  check "a base whose environment writes a shim naming $config: the hooks of the working tree stay as they were" \
    equals "$(hooks "$repo")" "$found"
done

# An environment that does not build gives no result either. The base run
# starts as devenv shell, which then becomes the harness, so the error names
# devenv shell, whichever of the two ended the run.
repo=$(two_commits)
echo 1 >"$repo/canned-devenv-exit"
commit "$repo" "chore: a commit whose environment does not build"
git -C "$repo" tag broken-environment
rm "$repo/canned-devenv-exit"
commit "$repo" "chore: a head whose environment builds"
compare "$repo" broken-environment
check "an environment that does not build at base: exits 1" equals "$code" 1
check "an environment that does not build at base: says so" \
  contains "$err" "compare-evals: the eval run at base wrote no result (devenv shell exited with status 1)"
check "an environment that does not build at base: runs nothing" equals "$calls" ""

# An interrupt ends the run as well. The run here never ends by itself, and
# the signal reaches the program alone. A command that a script starts in the
# background ignores the signal, so env gives it back its default.
repo=$(two_commits)
: >"$repo/canned-hang"
commit "$repo" "chore: a run that never ends"
remove "$tmp/scratch" && mkdir "$tmp/scratch"
(cd "$repo" && TMPDIR=$tmp/scratch DEVENV_ROOT=$repo PATH=$path \
  exec env --default-signal=INT "$program" main >/dev/null 2>&1 </dev/null) &
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

# An interrupt can come while devenv still enters the environment of the base
# commit, and a task of that environment, such as an old baseline's run of its
# git hooks over the checkout, ends with it too.
repo=$(two_commits)
: >"$repo/canned-devenv-hang"
commit "$repo" "chore: an environment whose task never ends"
: >"$FAKE_CLAUDE_PID"
: >"$FAKE_TASK_PID"
remove "$tmp/scratch" && mkdir "$tmp/scratch"
(cd "$repo" && TMPDIR=$tmp/scratch DEVENV_ROOT=$repo PATH=$path \
  exec env --default-signal=INT "$program" main >/dev/null 2>&1 </dev/null) &
program_pid=$!
for _ in {1..100}; do
  [[ ! -s $FAKE_TASK_PID ]] || break
  sleep 0.1
done
check "an interrupt during devenv: comes while a task runs" test -s "$FAKE_TASK_PID"
run_pid=$(<"$FAKE_CLAUDE_PID") task_pid=$(<"$FAKE_TASK_PID")
kill -INT "$program_pid"
code=0
wait "$program_pid" || code=$?
check "an interrupt during devenv: ends the program the way a signal does" equals "$code" 130
check "an interrupt during devenv: ends devenv" gone "$run_pid"
check "an interrupt during devenv: ends its task" gone "$task_pid"
check "an interrupt during devenv: nothing is left behind" nothing_left "$repo"
kill "$run_pid" "$task_pid" 2>/dev/null || true

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

# Git reads everything after `:/` as the text to search the messages for.
repo=$(two_commits)
compare "$repo" ':/chore: base'
check "a base given as a search of the messages: exits 0" equals "$code" 0
check "a base given as a search of the messages: is named by its commit" contains "$out" "base: $(sha "$repo" base) (:/chore: base)"$'\n'

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

# A case is looked up in the base commit by its hash, never by the name that
# the operator gave, which git could read as an option.
repo=$(two_commits)
result 0.25 "$(case_of plugins/one/evals/red-then-green 0 1)" >"$repo/canned-result.json"
commit "$repo" "chore: a base that has a case without a result" plugins/two/evals/new-at-head
git -C "$repo" update-ref refs/heads/--force HEAD
result 0.5 "$(case_of plugins/two/evals/new-at-head 1 1)" "$(case_of plugins/one/evals/red-then-green 1 1)" >"$repo/canned-result.json"
commit "$repo" "chore: the case gives a result at head"
compare "$repo" -- --force
check "a base that starts with a dash: a case that it has and gave no result for has no dash" contains "$out" "
plugins/two/evals/new-at-head     no result     1.00 (1 run)
"

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
# dash could be an option to it. No case, model or tool starts with one.
repo=$(two_commits)
for argument in --case=--publish-report --allow-tools=--publish-report --model=--output-dir=/elsewhere; do
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

# Nor does the harness get a value that names nothing: an empty one, which is
# what --model=$MODEL gives where the variable is not set, or one that opens
# or ends with white space. No case, model or tool has such a name.
for argument in --case= --model= --allow-tools=; do
  compare "$repo" main~1 "$argument"
  check "an empty value, $argument: is a usage error" equals "$code" 2
  check "an empty value, $argument: says so" \
    contains "$err" "compare-evals: error: argument ${argument%=}: a value cannot be empty"
  check "an empty value, $argument: runs nothing" equals "$calls" ""
done
for argument in "--case= --publish-report" "--model=sonnet " "--allow-tools= Write"; do
  compare "$repo" main~1 "$argument"
  check "a value with white space at an end, $argument: is a usage error" equals "$code" 2
  check "a value with white space at an end, $argument: says so" \
    contains "$err" "compare-evals: error: argument ${argument%%=*}: a value cannot open or end with white space: '${argument#*=}'"
  check "a value with white space at an end, $argument: runs nothing" equals "$calls" ""
done
compare "$repo" main~1 $'--case=\tred-then-green'
check "a value with a tab at an end: is a usage error" equals "$code" 2
check "a value with a tab at an end: says so, and shows the tab" \
  contains "$err" "compare-evals: error: argument --case: a value cannot open or end with white space: '\\tred-then-green'"
check "a value with a tab at an end: runs nothing" equals "$calls" ""

# No comparison has fewer than 1 run. The harness gets a number of runs as
# digits, without the white space that may stand in front of them on the
# command line.
for runs in 0 -1 ' -1'; do
  compare "$repo" main~1 "--runs=$runs"
  check "a number of runs below 1, '$runs': is a usage error" equals "$code" 2
  check "a number of runs below 1, '$runs': says so" \
    contains "$err" "compare-evals: error: argument --runs: a number of runs must be 1 or more: '$runs'"
  check "a number of runs below 1, '$runs': runs nothing" equals "$calls" ""
done
compare "$repo" main~1 --runs 0
check "a number of runs below 1 after a space: is a usage error" equals "$code" 2
check "a number of runs below 1 after a space: runs nothing" equals "$calls" ""
compare "$repo" main~1 --runs ' 3'
check "a number of runs after white space: reaches the harness as digits" contains "$calls" "--scaffold --runs 3"$'\n'

path=$without_claude
repo=$(two_commits)
compare "$repo" main~1
check "claude is not on the PATH: exits 1" equals "$code" 1
check "claude is not on the PATH: says so" contains "$err" "compare-evals: claude is not on the PATH"
check "claude is not on the PATH: nothing is left behind" nothing_left "$repo"
path=$without_devenv
compare "$repo" main~1
check "devenv is not on the PATH: exits 1" equals "$code" 1
check "devenv is not on the PATH: says so" contains "$err" "compare-evals: devenv is not on the PATH"
check "devenv is not on the PATH: runs nothing" equals "$calls" ""
path=$with_claude

# The run in the working tree keeps the environment that the program starts
# from, so that has to be the devenv shell of the working tree.
shell_root=$tmp/empty
compare "$repo" main~1
check "the devenv shell of another directory: exits 1" equals "$code" 1
check "the devenv shell of another directory: says so" contains "$err" \
  "compare-evals: start compare-evals from the devenv shell of the working tree $repo, not from the devenv shell of $tmp/empty"
check "the devenv shell of another directory: runs nothing" equals "$calls" ""
shell_root=""

compare "$tmp/empty" main
check "outside a repository: exits 1" equals "$code" 1
check "outside a repository: says so" contains "$err" "compare-evals: not inside a git repository"

if ((failures > 0)); then
  echo "test-compare-evals: $failures failure(s)" >&2
  exit 1
fi
echo "test-compare-evals: ok"
