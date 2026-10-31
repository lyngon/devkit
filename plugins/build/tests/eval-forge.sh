#!/usr/bin/env bash
# Exercise the stand-in for gh that the eval cases of build:pull-request put in front
# of the PATH, in a workspace that the seed script of pull-request-says-it-met-nothing
# writes: what it prints for each command, and what it records in .git/forge
# for the graders. Run through `devenv test`.
set -euo pipefail

evals=$(cd "$(dirname "${BASH_SOURCE[0]}")/../evals" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

cd "$tmp"
bash "$evals/pull-request-says-it-met-nothing/seed-workspace.sh" >/dev/null
forge=$tmp/.git/forge
branch=feat/reject-negative-quantity

# --- Assertions --------------------------------------------------------------

# gh <argument>...: run the stand-in, and leave what it printed on stdout in
# $out, on stderr in $err and its exit status in $code.
gh() {
  code=0
  out=$("$forge/bin/gh" "$@" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

check() {
  local label=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    echo "  expected: ${expected//$'\n'/$'\n'            }"
    echo "  actual:   ${actual//$'\n'/$'\n'            }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

gh auth status
check "auth status says it is signed in" \
  "0|github.com
  Logged in to github.com account acme-bot (keyring)
  - Active account: true" "$code|$out"

printf '## Why\n\nThe first body.\n' >"$tmp/body.md"
gh pr create --title "feat(pricing): reject a negative quantity" --body-file "$tmp/body.md"
check "pr create refuses a branch that is not pushed, and records nothing" \
  "1|aborted: you must first push the current branch to a remote, or use the --head flag|absent" \
  "$code|$err|$([[ -e "$forge/created.log" ]] && echo present || echo absent)"

git push -q origin "$branch"
gh pr create --title "feat(pricing): reject a negative quantity" --body-file "$tmp/body.md" --label bug
check "pr create prints the URL of the pull request" "0|https://github.com/acme/orders/pull/71|" "$code|$out|$err"
check "pr create records the body as it was given, under the name of the branch" \
  $'## Why\n\nThe first body.\nend' "$(cat "$forge/pulls/$branch.md"; echo end)"

gh pr create --title "again" --body "again"
check "pr create refuses a second pull request from the branch" \
  "1|a pull request for branch \"$branch\" into branch \"main\" already exists:
https://github.com/acme/orders/pull/71" "$code|$err"

gh issue create --title "refund() drops the currency" --body "Seen in the full check." --label bug
check "issue create prints the URL of the issue with the next number" \
  "0|https://github.com/acme/orders/issues/72" "$code|$out"
check "issue create records the issue" \
  $'# refund() drops the currency\n\nSeen in the full check.' "$(<"$forge/issues/72.md")"

gh issue create --title "no body"
check "issue create without a body fails as gh does when it cannot ask" \
  "1|must provide \`--title\` and \`--body\` (or \`--fill\`) when not running interactively" "$code|$err"

gh pr edit "$branch" --body "## Why

The second body."
check "pr edit replaces the body that the branch's record holds" \
  $'0|https://github.com/acme/orders/pull/71|## Why\n\nThe second body.' "$code|$out|$(<"$forge/pulls/$branch.md")"

gh pr view --json body,number --jq '"\(.number) \(.body)"'
check "pr view of the current branch answers --json and --jq" \
  $'0|71 ## Why\n\nThe second body.' "$code|$out"

gh pr view https://github.com/acme/orders/pull/71 --json title
check "pr view takes the URL of a pull request" \
  '0|{"title": "feat(pricing): reject a negative quantity"}' "$code|$out"

check "pr create records no comment yet" "" "$(<"$forge/pulls/$branch.comments.md")"

gh pr comment 71 --body "Evidence."
check "pr comment prints the URL of the comment" \
  "0|https://github.com/acme/orders/pull/71#issuecomment-7101" "$code|$out"

printf '| ts | phase |\n| --- | --- |\n' >"$tmp/trail.md"
gh pr comment "$branch" --body-file "$tmp/trail.md"
check "pr comment records each comment under the name of the branch, numbered" \
  $'<!-- comment 1 -->\nEvidence.\n<!-- comment 2 -->\n| ts | phase |\n| --- | --- |\n\nend' \
  "$(cat "$forge/pulls/$branch.comments.md"; echo end)"

gh pr checks
check "pr checks says that no checks ran, as gh does" "1|no checks reported on the '$branch' branch" "$code|$err"

gh issue view 99
check "issue view of a number that has no issue fails" \
  "1|GraphQL: Could not resolve to an issue or pull request with the number of 99." "$code|$err"

check "created.log holds one line per issue and pull request, in order" \
  "pull #71 $branch feat(pricing): reject a negative quantity
issue #72 refund() drops the currency" "$(<"$forge/created.log")"

gh api repos/acme/orders
check "a command the stand-in does not answer fails and says so" \
  "1|gh api repos/acme/orders: this forge answers only auth status, repo view, issue create, issue list, issue view, issue comment, pr create, pr edit, pr view, pr list, pr comment, pr checks" \
  "$code|$err"

if ((failures > 0)); then
  echo "test-eval-forge: $failures failure(s)" >&2
  exit 1
fi
echo "test-eval-forge: ok"
