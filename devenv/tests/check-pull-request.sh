#!/usr/bin/env bash
# Exercise check-pull-request on fixture titles and bodies: a pair that passes,
# and for each rule one that fails (the title, the seven headings, the marks
# prose-lint flags, the length). The built command is the one argument, so the
# fixtures run what the baseline module built, with the target and the headroom
# it wrote into the command. Other values of the two go to the Python file
# directly. Run through `devenv test`.
set -euo pipefail

built=${1:?usage: check-pull-request.sh <the built check-pull-request command>}
baseline=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
program=$baseline/check-pull-request.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# The Python file finds prose-lint on the PATH, where the built command puts it.
mkdir "$tmp/bin"
ln -s "$baseline/prose-lint.sh" "$tmp/bin/prose-lint"

# --- Fixture helpers ---------------------------------------------------------

good_title="feat(orders): reject a negative quantity"
sections=("Why" "Decisions" "What changed" "Scope" "Blast radius" "Verified" "Not verified")
ways_out="move a decision into a decision record, move evidence into a pull request comment, or split the change"

# body_of <section>...: a body with one content line under each section, in
# the order given. Every section takes four lines.
body_of() {
  local section
  for section in "$@"; do
    printf '## %s\n\n%s\n\n' "$section" "One line under this heading."
  done
}

# body <count>: a body with the seven sections and <count> content lines, seven
# at least.
body() {
  local i
  body_of "${sections[@]}"
  for ((i = 8; i <= $1; i++)); do
    echo "- One more line under the last heading."
  done
}

# lengths <target> <headroom>: the Python file with these two values, as the
# built command runs it with the values of the baseline.
lengths() {
  PATH="$tmp/bin:$PATH" python3 "$program" --target-lines "$1" --headroom-lines "$2"
}

# A commitizen that fails for a reason of its own, and prints what a workflow
# would take for a command.
mkdir "$tmp/broken"
printf '%s\n' '#!/usr/bin/env bash' 'echo "::error::forged" >&2' 'exit 19' >"$tmp/broken/cz"
chmod +x "$tmp/broken/cz"
with_broken_commitizen() {
  PATH="$tmp/broken:$tmp/bin:$PATH" python3 "$program" --target-lines 40 --headroom-lines 20
}

# --- Assertions --------------------------------------------------------------

# check <title> <body> <command> [argument...]: run the command on the title
# and the body, and leave its output in $output and its exit status in $status.
check() {
  local title=$1 text=$2
  shift 2
  status=0
  output=$(
    unset GITHUB_ACTIONS
    export PR_TITLE=$title PR_BODY=$text
    "$@" 2>&1
  ) || status=$?
}

fail() {
  echo "FAIL: $1: expected $2, got exit $status:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
}

# expect_silent <label>: the last run passed and printed nothing.
expect_silent() {
  if ((status == 0)) && [[ -z "$output" ]]; then
    echo "ok: $1"
  else
    fail "$1" "exit 0 and no output"
  fi
}

# expect <label> <status> <lines> <fragment>...: the last run exited with
# <status> and printed <lines> lines that hold every fragment. A fragment that
# starts with a newline must start a line.
expect() {
  local label=$1 wanted=$2 lines=$3 fragment printed
  shift 3
  printed=$(wc -l <<<"$output")
  if ((status != wanted)) || ((printed != lines)); then
    fail "$label" "exit $wanted and $lines line(s)"
    return
  fi
  for fragment in "$@"; do
    if [[ $'\n'"$output" != *"$fragment"* ]]; then
      fail "$label" "'$fragment'"
      return
    fi
  done
  echo "ok: $label"
}

# holds_command: the last output holds what a workflow would take for a command.
holds_command() {
  [[ "$output" == *"::"* || "$output" == *"##["* ]]
}

# --- Cases -------------------------------------------------------------------

good=$(body 7)

check "$good_title" "$good" "$built"
expect_silent "a good title and a good body pass with no output"

# The title
check "Add a thing" "$good" "$built"
expect "a title that is not a Conventional Commits subject fails" 1 1 \
  "error: title: commitizen rejects it as a Conventional Commits subject: write it as <type>(<scope>): <subject>"

check "Merge branch main into feat/orders" "$good" "$built"
expect "a title that commitizen lets through for a merge commit fails" 1 1 \
  "error: title: commitizen rejects it as a Conventional Commits subject"

check "" "$good" "$built"
expect "an empty title fails" 1 1 "error: title: PR_TITLE is empty"

check "$good_title"$'\n\nAnd a second paragraph.' "$good" "$built"
expect "a title of more than one line fails" 1 1 "error: title: it has more than one line"

check "--help" "$good" "$built"
expect "a title that looks like an option is checked as a title" 1 1 \
  "error: title: commitizen rejects it as a Conventional Commits subject"

check "feat(orders): say \$(touch $tmp/ran) and \`touch $tmp/ran\`" "$good" "$built"
if [[ -e "$tmp/ran" ]]; then
  fail "a title with shell syntax is never run" "no file at $tmp/ran"
else
  expect_silent "a title with shell syntax is text, and passes"
fi

check "$good_title" "$good" with_broken_commitizen
if holds_command; then
  fail "what a failed commitizen printed is not repeated" "no workflow command"
else
  expect "a commitizen that cannot check is a refusal, not a bad title" 2 1 \
    "check-pull-request: cz exited with status 19, so the title was not checked"
fi

# The headings
check "$good_title" "$(body_of "Why" "Decisions" "What changed" "Blast radius" "Verified" "Not verified")" "$built"
expect "a missing heading fails" 1 1 "error: body: '## Scope' is missing: add the section"

check "$good_title" "$(body_of "${sections[@]}" "Notes")" "$built"
expect "an extra heading fails" 1 1 "error: body:29: '## Notes' is not one of the seven headings"

check "$good_title" "$(body_of "Why" "Decisions" "Scope" "What changed" "Blast radius" "Verified" "Not verified")" "$built"
expect "a misordered heading fails" 1 1 \
  "error: body: the headings are out of order: write them as ## Why, ## Decisions, ## What changed, ## Scope, ## Blast radius, ## Verified, ## Not verified"

check "$good_title" "$(body_of "${sections[@]}" "Why")" "$built"
expect "a heading that is there twice fails" 1 1 "error: body:29: '## Why' is there a second time"

check "$good_title" "${good/"## Why"/"## why"}" "$built"
expect "a heading in another spelling is an extra one, and its section is missing" 1 2 \
  "error: body:1: '## why' is not one of the seven headings" "error: body: '## Why' is missing"

check "$good_title" "$good"$'\n\n```sh\n## main...origin/main\n## Why\n```' "$built"
expect_silent "a line inside a fenced code block is no heading"

check "$good_title" "$good"$'\n\n## ::warning::forged ##[error]forged' "$built"
if holds_command; then
  fail "an extra heading is named without its workflow command" "no workflow command"
else
  expect "an extra heading that holds a workflow command fails" 1 1 "error: body:29: '"
fi

check "$good_title" "" "$built"
expect "an empty body fails" 1 1 "error: body: PR_BODY is empty: write the seven sections"

check "" "" "$built"
expect "with neither variable set, the title and the body each fail" 1 2 \
  "error: title: PR_TITLE is empty" "error: body: PR_BODY is empty"

check "$good_title" "${good//$'\n'/$'\r\n'}" "$built"
expect_silent "a body with the line endings of a web form passes"

# The marks prose-lint flags
check "$good_title"$' \xe2\x80\x94 at last' "$good" "$built"
expect "an em dash in the title fails" 1 1 "error: title:1: em dash (U+2014): use a comma, a period or parentheses"

check "$good_title" "$good"$'\nIt covers pages 3\xe2\x80\x935.' "$built"
expect "an en dash in the body fails" 1 1 "error: body:28: en dash (U+2013): use a hyphen or the word \"to\""

check "$good_title" "$good"$'\nThe \xe2\x80\x9cfast\xe2\x80\x9d path.' "$built"
expect "a curly quote in the body fails" 1 2 \
  "error: body:28: curly double quote (U+201C): use a straight double quote" \
  "error: body:28: curly double quote (U+201D): use a straight double quote"

# The length, with the values the baseline wrote into the built command
check "$good_title" "$(body 40)" "$built"
expect_silent "a body exactly at the target passes with no output"

check "$good_title" "$(body 41)" "$built"
expect "a body one line over the target passes with a warning that holds the numbers" 0 1 \
  "warning: body is 41 content lines, limit is 60 (target 40 plus headroom 20): over the target" "$ways_out"

check "$good_title" "$(body 60)" "$built"
expect "a body exactly at the limit passes with a warning" 0 1 \
  "warning: body is 60 content lines, limit is 60 (target 40 plus headroom 20)"

check "$good_title" "$(body 61)" "$built"
expect "a body one line over the limit fails with the numbers" 1 1 \
  "error: body is 61 content lines, limit is 60 (target 40 plus headroom 20): over the limit" "$ways_out"

check "$good_title" "$(body 41)" env GITHUB_ACTIONS=true "$built"
expect "under GitHub Actions a warning is also a workflow annotation" 0 2 \
  "warning: body is 41 content lines" \
  $'\n'"::warning::body is 41 content lines, limit is 60 (target 40 plus headroom 20)"

check "$good_title" "$(body 61)" env GITHUB_ACTIONS=true "$built"
expect "under GitHub Actions a failure stays one line" 1 1 "error: body is 61 content lines"

check "$good_title" "$good" "$built" --target-lines 400
expect "the built command takes no arguments, so nobody raises its two values" 2 1 \
  "check-pull-request: takes no arguments"

# The length, with other values
check "$good_title" "$(body 40)" lengths 40 0
expect_silent "with a headroom of 0, a body at the target passes with no output"

check "$good_title" "$(body 41)" lengths 40 0
expect "with a headroom of 0, a body one line over the target fails" 1 1 \
  "error: body is 41 content lines, limit is 40 (target 40 plus headroom 0): over the limit"

check "$good_title" "$(body 12)" lengths 10 5
expect "another target and headroom show in the warning" 0 1 \
  "warning: body is 12 content lines, limit is 15 (target 10 plus headroom 5)"

if ((failures > 0)); then
  echo "test-check-pull-request: $failures failure(s)" >&2
  exit 1
fi
echo "test-check-pull-request: ok"
