#!/usr/bin/env bash
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
closes="Closes nothing."
no_closes_line="error: body: '## Why' does not end with a line that says which issues the change closes: end the section with \"Closes nothing.\" or with each issue that the change fixes, as \"Closes #12, closes #15.\""
bad_closes_line="the line \"Closes\" says neither \"nothing\" nor a list of issues that GitHub closes: write \"Closes nothing.\" or name each issue as #12 or owner/repository#12, with \"closes\" before each one, as \"Closes #12, closes #15.\""
stray_keyword="a closing keyword stands outside the line that ends '## Why', and GitHub closes the issue after it when the pull request merges: name the issue in that line, or reword so that no \"close\", \"fix\" or \"resolve\" comes right before an issue"
title_keyword="error: title: a closing keyword stands in the title, and GitHub closes the issue after it when the commit lands: name the issue in the line that ends '## Why', or reword the title so that no \"close\", \"fix\" or \"resolve\" comes right before an issue"
met="Met on the way: nothing."
no_met_line="error: body: '## Scope' does not end with a line that says what the work met on the way: end the section with \"Met on the way: nothing.\" or with each issue and pull request for a problem the work met, as \"Met on the way: #12 and #15.\""
bad_met_line="the line \"Met on the way:\" says neither \"nothing\" nor a list of issues and pull requests: write \"Met on the way: nothing.\" or name each one as #12 or owner/repository#12, joined by commas and \"and\""

body_of() {
  local section line
  for section in "$@"; do
    line="One line under this heading."
    if [[ $section == "Why" ]]; then
      line=$closes
    elif [[ $section == "Scope" ]]; then
      line=$met
    fi
    printf '## %s\n\n%s\n\n' "$section" "$line"
  done
}

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
closes_at=$(grep -n -x -F "$closes" <<<"$good" | cut -d: -f1)
met_at=$(grep -n -x -F "$met" <<<"$good" | cut -d: -f1)

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
check "$good_title" "$(body_of "Why" "Decisions" "What changed" "Scope" "Verified" "Not verified")" "$built"
expect "a missing heading fails" 1 1 "error: body: '## Blast radius' is missing: add the section"

check "$good_title" "$(body_of "Why" "Decisions" "What changed" "Blast radius" "Verified" "Not verified")" "$built"
expect "a body without Scope also lacks the line that ends it" 1 2 \
  "error: body: '## Scope' is missing: add the section" $'\n'"$no_met_line"

check "$good_title" "$(body_of "${sections[@]}" "Notes")" "$built"
expect "an extra heading fails" 1 1 "error: body:29: '## Notes' is not one of the seven headings"

check "$good_title" "$(body_of "Why" "Decisions" "Scope" "What changed" "Blast radius" "Verified" "Not verified")" "$built"
expect "a misordered heading fails" 1 1 \
  "error: body: the headings are out of order: write them as ## Why, ## Decisions, ## What changed, ## Scope, ## Blast radius, ## Verified, ## Not verified"

check "$good_title" "$(body_of "${sections[@]}" "Why")" "$built"
expect "a heading that is there twice fails" 1 1 "error: body:29: '## Why' is there a second time"

check "$good_title" "${good/"## Why"/"## why"}" "$built"
expect "a heading in another spelling is an extra one, and its section and its line are missing" 1 3 \
  "error: body:1: '## why' is not one of the seven headings" "error: body: '## Why' is missing" $'\n'"$no_closes_line"

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

why_of_137=$'Under `/build:auto`, step 3 of `build:clean-comments` told the lead to fix trivial flags itself, which `lead-writes-no-code.py` refuses for an Edit or a Write (#126).
A lead that used `sed` through Bash instead wrote the code, and nothing stopped it.
Now the skill gives every fix to a `build:implementer` delegate under the mode, and the hook reads the lead\'s shell commands too.'
check "$good_title" "${good/"$closes"/"$why_of_137"}" "$built"
expect "a Why without the line fails, as the Why of pull request 137 would have" 1 1 "$no_closes_line"

why_of_129=$'Claude Code loads a file that a rule under `.claude/rules/` imports with `@` at launch, whatever the rule\'s `paths:` say.
A scoped rule that imports a document therefore loads it into every session, and no check failed.
`validate-documents` now fails such a rule and names the fix.

Closes #124'
check "$good_title" "${good/"$closes"/"$why_of_129"}" "$built"
expect_silent "a Why that ends with the issue it closes passes, as the Why of pull request 129 does"

check "$good_title" "${good/"$closes"/"Closes #12, closes #15, closes lyngon/devkit#63."}" "$built"
expect_silent "a line that names closes before each issue passes"

check "$good_title" "${good/"$closes"/"Closes nothing"}" "$built"
expect_silent "a line that closes nothing passes, with or without the period"

check "$good_title" "${good/"$closes"/"Closes #12 and #15."}" "$built"
expect "a list of which GitHub would close only the first issue fails" 1 1 "error: body:$closes_at: $bad_closes_line"

check "$good_title" "${good/"$closes"/"Closes"}" "$built"
expect "a line with nothing after the word fails" 1 1 "error: body:$closes_at: $bad_closes_line"

check "$good_title" "${good/"$closes"/"Closes #12 for the values that name nothing."}" "$built"
expect "an issue with a remark after it fails" 1 1 "error: body:$closes_at: $bad_closes_line"

check "$good_title" "${good/"$closes"/"Fixes #12."}" "$built"
expect "another keyword in place of Closes fails, and closes the issue outside the line" 1 2 \
  "$no_closes_line" $'\n'"error: body:$closes_at: $stray_keyword"

check "$good_title" "${good/"$closes"/"$closes"$'\n\nThe README stays as it is.'}" "$built"
expect "a line that does not end Why fails" 1 1 "$no_closes_line"

check "$good_title" "${good/"$closes"/$'```text\n'"$closes"$'\n```'}" "$built"
expect "a line inside a fenced code block at the end of Why fails" 1 1 "$no_closes_line"

check "$good_title" "${good/"$closes"/"Closes ::warning::forged ##[error]forged"}" "$built"
if holds_command; then
  fail "a line about closing that is not well formed is named without its text" "no workflow command"
else
  expect "a line about closing that holds a workflow command fails" 1 1 "error: body:$closes_at: $bad_closes_line"
fi

# shellcheck disable=SC2016  # the backticks are Markdown, not a command
verified_of_142='- Three headless `/build:pull-request` sessions per arm on sonnet for each case. At head, Why ended with `Closes #64.` in 3 of 3 runs and with `Closes nothing.` in 3 of 3. At base it did in 0 of 6. The three base runs told that the branch fixes #64 still wrote a keyword that GitHub honors ("Fixes #64"), only not as the line, so the case measures the form of the line.'
with_verified_of_142=${good/$'## Verified\n\nOne line under this heading.'/$'## Verified\n\n'"$verified_of_142"}
check "$good_title" "$with_verified_of_142" "$built"
expect "a closing keyword in Verified fails, as the Verified of pull request 142 would have" 1 1 \
  "error: body:$(grep -n -x -F -- "$verified_of_142" <<<"$with_verified_of_142" | cut -d: -f1): $stray_keyword"

check "$good_title" "${good/"$closes"/$'This fixes #12 in part.\n\n'"$closes"}" "$built"
expect "a closing keyword in Why above its line fails" 1 1 "error: body:$closes_at: $stray_keyword"

check "$good_title" "$good"$'\n\nIt resolves https://github.com/lyngon/devkit/issues/12, and Resolved: #13.' "$built"
expect "a closing keyword before the address of an issue, or in capitals with a colon, fails" 1 1 \
  "error: body:29: $stray_keyword"

check "$good_title" "$good"$'\n\n```text\nfixes #12\n```' "$built"
expect "a closing keyword in a fenced code block fails as well" 1 1 "error: body:30: $stray_keyword"

check "$good_title" "$good"$'\n\nThe fix of #12 and the prefixes #13 stay.' "$built"
expect_silent "a word that is no closing keyword before an issue passes"

check "fix(orders): resolve #12" "$good" "$built"
expect "a closing keyword in the title fails" 1 1 "$title_keyword"

# The line that ends Scope
# shellcheck disable=SC2016  # the backticks are Markdown, not a command
scope_of_56='`compare-evals` and its fixture test.
The README stays as it is, since the usage error names the option and the value.'
check "$good_title" "${good/"$met"/"$scope_of_56"}" "$built"
expect "a Scope without the line fails, as the Scope of pull request 56 would have" 1 1 "$no_met_line"

check "$good_title" "${good/"$met"/"Met on the way:"}" "$built"
expect "a line with nothing after the colon fails" 1 1 "error: body:$met_at: $bad_met_line"

check "$good_title" "${good/"$met"/"Met on the way:   "}" "$built"
expect "a line with only spaces after the colon fails" 1 1 "error: body:$met_at: $bad_met_line"

check "$good_title" "${good/"$met"/"Met on the way: nothing"}" "$built"
expect_silent "a line that says nothing passes, with or without the period"

check "$good_title" "${good/"$met"/"Met on the way: #60, #61, and lyngon/devkit#63."}" "$built"
expect_silent "a line that lists issues and pull requests passes"

check "$good_title" "${good/"$met"/"Met on the way: #60 and #63"}" "$built"
expect_silent "a list of two joined by and passes"

check "$good_title" "${good/"$met"/"Met on the way: a stale commit-msg shim, which is harmless."}" "$built"
expect "a remark in place of a list fails" 1 1 "error: body:$met_at: $bad_met_line"

check "$good_title" "${good/"$met"/"Met on the way: #60 for the values that name nothing."}" "$built"
expect "a reference with a remark after it fails" 1 1 "error: body:$met_at: $bad_met_line"

check "$good_title" "${good/"$met"/"Met on the way: None."}" "$built"
expect "None in place of nothing fails" 1 1 "error: body:$met_at: $bad_met_line"

check "$good_title" "${good/"$met"/"$met"$'\n\nLeaves out the README.'}" "$built"
expect "a line that does not end Scope fails" 1 1 "$no_met_line"

check "$good_title" "${good/"$met"/$'```text\n'"$met"$'\n```'}" "$built"
expect "a line inside a fenced code block at the end of Scope fails" 1 1 "$no_met_line"

check "$good_title" "${good/"$met"/"Met on the way: ::warning::forged ##[error]forged"}" "$built"
if holds_command; then
  fail "a line that is not well formed is named without its text" "no workflow command"
else
  expect "a line that holds a workflow command fails" 1 1 "error: body:$met_at: $bad_met_line"
fi

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
