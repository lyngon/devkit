#!/usr/bin/env bash
# Exercise the correction skill's prune-mistakes.py against throwaway ledgers:
# which files it deletes, and that it deletes nothing when it cannot read the
# limit or a date. Every run of the script gets an empty environment whose PATH
# is this file's one argument, the directories of the tools in the baseline's
# lyngon.scriptTools, since that list is all a shipped script may run. Run
# through `devenv test`.
set -euo pipefail

if (($# != 1)); then
  echo "usage: prune-mistakes.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
script=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/correction/scripts/prune-mistakes.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# --- Fixture helpers ---------------------------------------------------------

new_repo() {
  mktemp -d "$tmp/repo.XXXXXX"
}

# mistake <repo> <name> [line...]: a ledger file whose heading is followed by
# the given lines, which is where its date goes.
mistake() {
  local repo=$1 name=$2
  shift 2
  mkdir -p "$repo/docs/mistakes"
  printf '%s\n' "# A generated client was edited by hand" "" "$@" "" \
    "The agent edited the client where it should have changed the schema." >"$repo/docs/mistakes/$name.md"
}

# A ledger with one file on each side of a limit of 365 days and of 30 days,
# counted from 2026-10-13.
aged_ledger() {
  local repo
  repo=$(new_repo)
  mistake "$repo" caught-two-years-ago "- **Date**: 2024-10-13"
  mistake "$repo" caught-366-days-ago "- **Date**: 2025-10-12"
  mistake "$repo" caught-365-days-ago "- **Date**: 2025-10-13"
  mistake "$repo" caught-this-month "- **Date**: 2026-10-01" \
    "- **Caught in**: [feat(orders): add the client](https://example.com/pull/7)"
  echo "$repo"
}

# --- Assertions --------------------------------------------------------------

# prune <repo> <limit> [argument...]: run the script in the repository with the
# limit in its environment, and keep its output and its exit status.
prune() {
  local repo=$1 limit=$2
  shift 2
  status=0
  output=$(cd "$repo" && env -i PATH="$script_tools" LYNGON_MISTAKES_MAX_AGE_DAYS="$limit" "$script" "$@" 2>&1) || status=$?
}

# kept <repo>: the names of the files left in the ledger, on one line.
kept() {
  local path names=()
  for path in "$1"/docs/mistakes/*; do
    [[ -e "$path" ]] && names+=("${path##*/}")
  done
  echo "${names[*]}"
}

# expect <label> <repo> <status> <files left> <line of output>: the last run
# exited with the status, printed the line and left exactly those files.
expect() {
  local label=$1 repo=$2 wanted_status=$3 wanted_files=$4 line=$5 files
  files=$(kept "$repo")
  if ((status == wanted_status)) && [[ "$files" == "$wanted_files" ]] && grep -qxF -- "$line" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected exit $wanted_status, the files '$wanted_files' and the line '$line'"
    echo "  got exit $status, the files '$files' and:"
    echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

every_file="caught-365-days-ago.md caught-366-days-ago.md caught-this-month.md caught-two-years-ago.md"

# --- Cases -------------------------------------------------------------------

repo=$(aged_ledger)
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
mistake "$repo" caught-long-ago "- **Date**: 2000-01-01"
mistake "$repo" caught-in-the-future "- **Date**: 2999-01-01"
prune "$repo" 365
expect "without --today the age counts from today" "$repo" 0 "caught-in-the-future.md" \
  "prune-mistakes: deleted 1 of 2 ledger files, the limit is 365 days"

repo=$(new_repo)
prune "$repo" 365
expect "a repository without a ledger has nothing to prune" "$repo" 0 "" \
  "prune-mistakes: no docs/mistakes/ in $repo, so nothing to prune"

# A date that cannot be read: nothing is deleted, the old files included.
repo=$(aged_ledger)
mistake "$repo" no-date "- **Caught in**: [feat(orders): add the client](https://example.com/pull/7)"
prune "$repo" 365 --today 2026-10-13
expect "a file without a date line stops the run" "$repo" 1 "$every_file no-date.md" \
  "prune-mistakes: docs/mistakes/no-date.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 0; nothing was deleted"

repo=$(aged_ledger)
mistake "$repo" date-in-words "- **Date**: 12 October 2026"
prune "$repo" 365 --today 2026-10-13
expect "a date in another form stops the run" "$repo" 1 "$every_file date-in-words.md" \
  "prune-mistakes: docs/mistakes/date-in-words.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 0; nothing was deleted"

repo=$(aged_ledger)
mistake "$repo" two-dates "- **Date**: 2026-10-01" "- **Date**: 2024-10-01"
prune "$repo" 365 --today 2026-10-13
expect "two date lines stop the run" "$repo" 1 "$every_file two-dates.md" \
  "prune-mistakes: docs/mistakes/two-dates.md: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has 2; nothing was deleted"

repo=$(aged_ledger)
mistake "$repo" no-such-day "- **Date**: 2026-02-30"
prune "$repo" 365 --today 2026-10-13
expect "a day that does not exist stops the run" "$repo" 1 "$every_file no-such-day.md" \
  "prune-mistakes: docs/mistakes/no-such-day.md: '2026-02-30' is no date; nothing was deleted"

# A limit that cannot be read: nothing is deleted either.
repo=$(aged_ledger)
status=0
output=$(cd "$repo" && env -i PATH="$script_tools" "$script" --today 2026-10-13 2>&1) || status=$?
expect "without the variable the run stops" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is not set; the baseline sets it from lyngon.mistakes.maxAgeDays, so run this in the devenv shell of the repository; nothing was deleted"

prune "$repo" "a year" --today 2026-10-13
expect "a limit in words stops the run" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is 'a year', and the limit is a positive whole number of days; nothing was deleted"

prune "$repo" 0 --today 2026-10-13
expect "a limit of 0 stops the run" "$repo" 1 "$every_file" \
  "prune-mistakes: LYNGON_MISTAKES_MAX_AGE_DAYS is '0', and the limit is a positive whole number of days; nothing was deleted"

if ((failures > 0)); then
  echo "test-prune-mistakes: $failures failure(s)" >&2
  exit 1
fi
echo "test-prune-mistakes: ok"
