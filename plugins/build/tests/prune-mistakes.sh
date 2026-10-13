#!/usr/bin/env bash
# Exercise the correction skill's prune-mistakes.py against throwaway ledgers:
# which files it deletes, that it deletes nothing when it cannot read the
# limit or a date, and that the baseline's validate-documents fails every
# ledger file that stops it. Every run of the script gets an empty environment
# whose PATH is this file's one argument, the directories of the tools in the
# baseline's lyngon.scriptTools, since that list is all a shipped script may
# run. Run through `devenv test`.
set -euo pipefail

if (($# != 1)); then
  echo "usage: prune-mistakes.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
devkit=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
script=$devkit/plugins/build/skills/correction/scripts/prune-mistakes.py
validator=$devkit/devenv/validate-documents.py
# The physical path, which is the one the script prints for its working directory.
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
failures=0

# --- Fixture helpers ---------------------------------------------------------

# The root of a repository, as far as the script and the validator look: a
# .git, and the agent file that the validator demands of every repository.
new_repo() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  mkdir -p "$repo/.git" "$repo/.claude" "$repo/docs/mistakes"
  echo "@../INTENT.md" >"$repo/.claude/CLAUDE.md"
  echo "$repo"
}

# mistake <repo> <path under docs/mistakes> [line...]: a ledger file whose
# heading is followed by the given lines, which is where its date goes.
mistake() {
  local repo=$1 path=$2
  shift 2
  mkdir -p "$(dirname "$repo/docs/mistakes/$path")"
  printf '%s\n' "# A generated client was edited by hand" "" "$@" "" \
    "The agent edited the client where it should have changed the schema." >"$repo/docs/mistakes/$path"
}

# A ledger with one file on each side of a limit of 365 days and of 30 days,
# counted from 2026-10-13.
aged_ledger() {
  local repo
  repo=$(new_repo)
  mistake "$repo" caught-two-years-ago.md "- **Date**: 2024-10-13"
  mistake "$repo" caught-366-days-ago.md "- **Date**: 2025-10-12"
  mistake "$repo" caught-365-days-ago.md "- **Date**: 2025-10-13"
  mistake "$repo" caught-this-month.md "- **Date**: 2026-10-01" \
    "- **Caught in**: [feat(orders): add the client](https://example.com/pull/7)"
  echo "$repo"
}

# --- Assertions --------------------------------------------------------------

# prune <directory> <limit> [argument...]: run the script in the directory with
# the limit in its environment, and keep its output and its exit status.
prune() {
  local directory=$1 limit=$2
  shift 2
  status=0
  output=$(cd "$directory" && env -i PATH="$script_tools" LYNGON_MISTAKES_MAX_AGE_DAYS="$limit" "$script" "$@" 2>&1) || status=$?
}

# kept <repo>: the names directly in the ledger that are left, on one line.
kept() {
  local path names=()
  for path in "$1"/docs/mistakes/*; do
    [[ -e "$path" ]] && names+=("${path##*/}")
  done
  echo "${names[*]}"
}

# expect <label> <repo> <status> <names left> <line of output>: the last run
# exited with the status, printed the line and left exactly those names.
expect() {
  local label=$1 repo=$2 wanted_status=$3 wanted_names=$4 line=$5 names
  names=$(kept "$repo")
  if ((status == wanted_status)) && [[ "$names" == "$wanted_names" ]] && grep -qxF -- "$line" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected exit $wanted_status, the names '$wanted_names' and the line '$line'"
    echo "  got exit $status, the names '$names' and:"
    echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_validator <label> <repo> <line of output>: validate-documents, handed
# every file directly in the ledger, prints the line.
expect_validator() {
  local label=$1 repo=$2 line=$3 validation
  validation=$(cd "$repo" && env -i PATH="$script_tools" python3 "$validator" docs/mistakes/* 2>&1) || true
  if grep -qF -- "$line" <<<"$validation"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected validate-documents to print '$line', got:"
    echo "  ${validation//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

every_file="caught-365-days-ago.md caught-366-days-ago.md caught-this-month.md caught-two-years-ago.md"

# --- What it deletes ---------------------------------------------------------

repo=$(aged_ledger)
expect_validator "validate-documents passes the ledger that the next cases prune" "$repo" "validate-documents: ok"
prune "$repo" 365 --today 2026-10-13
expect "a file older than the limit is deleted, one at the limit stays" "$repo" 0 \
  "caught-365-days-ago.md caught-this-month.md" \
  "prune-mistakes: deleted 2 of 4 ledger files, the limit is 365 days"
expect "a deleted file is named with its date" "$repo" 0 \
  "caught-365-days-ago.md caught-this-month.md" \
  "prune-mistakes: deleted docs/mistakes/caught-366-days-ago.md, dated 2025-10-12"

prune "$repo" 365 --today 2026-10-13
expect "a second run finds nothing left to delete" "$repo" 0 \
  "caught-365-days-ago.md caught-this-month.md" \
  "prune-mistakes: deleted 0 of 2 ledger files, the limit is 365 days"

repo=$(aged_ledger)
prune "$repo" 30 --today 2026-10-13
expect "the limit comes from the environment" "$repo" 0 "caught-this-month.md" \
  "prune-mistakes: deleted 3 of 4 ledger files, the limit is 30 days"

repo=$(new_repo)
mistake "$repo" caught-long-ago.md "- **Date**: 2000-01-01"
mistake "$repo" caught-in-the-future.md "- **Date**: 2999-01-01"
prune "$repo" 365
expect "without --today the age counts from today" "$repo" 0 "caught-in-the-future.md" \
  "prune-mistakes: deleted 1 of 2 ledger files, the limit is 365 days"

repo=$(new_repo)
rmdir "$repo/docs/mistakes"
prune "$repo" 365
expect "a repository without a ledger has nothing to prune" "$repo" 0 "" \
  "prune-mistakes: no docs/mistakes/ in this repository, so nothing to prune"

# Only the Markdown files directly in the ledger are ledger files. What an
# editor or a person left beside them is neither read nor deleted.
repo=$(new_repo)
mistake "$repo" caught-two-years-ago.md "- **Date**: 2024-10-13"
mistake "$repo" notes.txt "- **Date**: 2024-10-13"
mistake "$repo" drafts/caught-two-years-ago.md "- **Date**: 2024-10-13"
echo "no date here" >"$repo/docs/mistakes/caught-two-years-ago.md~"
prune "$repo" 365 --today 2026-10-13
expect "what is no Markdown file directly in the ledger is left alone" "$repo" 0 \
  "caught-two-years-ago.md~ drafts notes.txt" \
  "prune-mistakes: deleted 1 of 1 ledger files, the limit is 365 days"
if [[ -e "$repo/docs/mistakes/drafts/caught-two-years-ago.md" ]]; then
  echo "ok: a file in a directory of the ledger is left alone"
else
  echo "FAIL: a file in a directory of the ledger is left alone: it is gone"
  failures=$((failures + 1))
fi

# validate-documents reads a file with bytes that are no UTF-8, so the script does too.
repo=$(new_repo)
printf '# A generated client was edited by hand\n\n- **Date**: 2024-10-13\n\nThe client said \xff\xfe.\n' \
  >"$repo/docs/mistakes/caught-two-years-ago.md"
expect_validator "validate-documents passes a file with bytes that are no UTF-8" "$repo" "validate-documents: ok"
prune "$repo" 365 --today 2026-10-13
expect "a file with bytes that are no UTF-8 is aged like any other" "$repo" 0 "" \
  "prune-mistakes: deleted 1 of 1 ledger files, the limit is 365 days"

# --- What stops it -----------------------------------------------------------

# A date that cannot be read: nothing is deleted, the old files included, and
# validate-documents fails the same file, so such a file is never committed.
repo=$(aged_ledger)
mistake "$repo" no-date.md "- **Caught in**: [feat(orders): add the client](https://example.com/pull/7)"
prune "$repo" 365 --today 2026-10-13
expect "a file without a date line stops the run" "$repo" 1 "$every_file no-date.md" \
  "prune-mistakes: docs/mistakes/no-date.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 0; nothing was deleted"
expect_validator "validate-documents fails a file without a date line" "$repo" \
  "error: docs/mistakes/no-date.md: ledger-file-shape:"

repo=$(aged_ledger)
mistake "$repo" date-in-words.md "- **Date**: 12 October 2026"
prune "$repo" 365 --today 2026-10-13
expect "a date in another form stops the run" "$repo" 1 "$every_file date-in-words.md" \
  "prune-mistakes: docs/mistakes/date-in-words.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 0; nothing was deleted"
expect_validator "validate-documents fails a date in another form" "$repo" \
  "error: docs/mistakes/date-in-words.md:3: ledger-file-shape:"

repo=$(aged_ledger)
mistake "$repo" two-dates.md "- **Date**: 2026-10-01" "- **Date**: 2024-10-01"
prune "$repo" 365 --today 2026-10-13
expect "two date lines stop the run" "$repo" 1 "$every_file two-dates.md" \
  "prune-mistakes: docs/mistakes/two-dates.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 2; nothing was deleted"
expect_validator "validate-documents fails two date lines" "$repo" \
  "error: docs/mistakes/two-dates.md: ledger-file-shape:"

repo=$(aged_ledger)
mistake "$repo" no-such-day.md "- **Date**: 2026-02-30"
prune "$repo" 365 --today 2026-10-13
expect "a day that does not exist stops the run" "$repo" 1 "$every_file no-such-day.md" \
  "prune-mistakes: docs/mistakes/no-such-day.md: '2026-02-30' is no date; nothing was deleted"
expect_validator "validate-documents fails a day that does not exist" "$repo" \
  "error: docs/mistakes/no-such-day.md:3: ledger-file-shape:"

# A limit that cannot be read: nothing is deleted either.
repo=$(aged_ledger)
status=0
output=$(cd "$repo" && env -i PATH="$script_tools" "$script" --today 2026-10-13 2>&1) || status=$?
expect "without the variable the run stops" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is not set; the baseline sets it from lyngon.mistakes.maxAgeDays, so run this in the devenv shell of the repository, and where that shell lacks it too, the repository's baseline is older than this script: run 'devenv update lyngon'; nothing was deleted"

prune "$repo" "a year" --today 2026-10-13
expect "a limit in words stops the run" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is 'a year', and the limit is a positive whole number of days; nothing was deleted"

prune "$repo" 0 --today 2026-10-13
expect "a limit of 0 stops the run" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is '0', and the limit is a positive whole number of days; nothing was deleted"

# Another directory than the root would have no ledger to find.
prune "$repo/docs" 365 --today 2026-10-13
expect "outside the root of the repository the run stops" "$repo" 1 "$every_file" \
  "prune-mistakes: $repo/docs has no .git; run this from the root of the repository; nothing was deleted"

if ((failures > 0)); then
  echo "test-prune-mistakes: $failures failure(s)" >&2
  exit 1
fi
echo "test-prune-mistakes: ok"
