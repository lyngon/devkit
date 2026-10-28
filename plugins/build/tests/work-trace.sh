#!/usr/bin/env bash
# Exercise the work-trace skill's trace.py against throwaway logs: the rows that
# append writes, the cells it keeps on one line and away from a spreadsheet's
# formulas, the Markdown table that table prints, and the logs and arguments
# that it refuses. Every run of the script gets an empty environment whose PATH
# is this file's one argument, the directories of the tools in the baseline's
# lyngon.scriptTools, since that list is all a shipped script may run. Run
# through `devenv test`.
set -euo pipefail

if (($# != 1)); then
  echo "usage: work-trace.sh <the PATH that holds the script tools>" >&2
  exit 2
fi
script_tools=$1
devkit=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
script=$devkit/plugins/build/skills/work-trace/scripts/trace.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

header=$'ts\tphase\tdecision\twhy\tevidence\tresult'
stamp='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

# trace <directory> <argument...>: run the script in the directory, and keep
# its output and its exit status.
trace() {
  local directory=$1
  shift
  status=0
  output=$(cd "$directory" && env -i PATH="$script_tools" "$script" "$@" 2>&1) || status=$?
}

new_directory() {
  mktemp -d "$tmp/work.XXXXXX"
}

pass() {
  echo "ok: $1"
}

fail() {
  echo "FAIL: $1: $2"
  failures=$((failures + 1))
}

# expect_log <label> <log> <extended regex per line...>: the log has exactly
# that many lines, each matching its pattern from start to end.
expect_log() {
  local label=$1 log=$2
  shift 2
  local lines=()
  mapfile -t lines <"$log"
  if ((status != 0)); then
    fail "$label" "expected exit 0, got $status and: $output"
    return
  fi
  if ((${#lines[@]} != $#)); then
    fail "$label" "expected $# lines, got ${#lines[@]}:"$'\n'"$(cat "$log")"
    return
  fi
  local index=0 pattern
  for pattern in "$@"; do
    if ! [[ "${lines[index]}" =~ ^${pattern}$ ]]; then
      fail "$label" "line $((index + 1)) is '${lines[index]}', expected /$pattern/"
      return
    fi
    index=$((index + 1))
  done
  pass "$label"
}

# expect_output <label> <status> <expected output>: the last run exited with
# the status and printed exactly that.
expect_output() {
  local label=$1 wanted_status=$2 wanted=$3
  if ((status == wanted_status)) && [[ "$output" == "$wanted" ]]; then
    pass "$label"
  else
    fail "$label" "expected exit $wanted_status and:"$'\n'"  ${wanted//$'\n'/$'\n'  }"$'\n'"  got exit $status and:"$'\n'"  ${output//$'\n'/$'\n'  }"
  fi
}

# --- append ------------------------------------------------------------------

work=$(new_directory)
trace "$work" append tmp/work-trace/move-the-widgets.tsv frame "counted the work first" "wanted the size" "commit 3a9f1c2" "found 5 things"
expect_log "the first row creates the directory and the log, after the header" "$work/tmp/work-trace/move-the-widgets.tsv" \
  "$header" \
  "${stamp}"$'\t''frame'$'\t''counted the work first'$'\t''wanted the size'$'\t''commit 3a9f1c2'$'\t''found 5 things'

trace "$work" append tmp/work-trace/move-the-widgets.tsv widget "moved the styles" "keep it small" "commit 7c21e0a" "tests pass"
expect_log "a later row is appended without a second header" "$work/tmp/work-trace/move-the-widgets.tsv" \
  "$header" \
  "${stamp}"$'\t''frame'$'\t'.* \
  "${stamp}"$'\t''widget'$'\t''moved the styles'$'\t''keep it small'$'\t''commit 7c21e0a'$'\t''tests pass'

work=$(new_directory)
: >"$work/empty.tsv"
trace "$work" append empty.tsv frame "began" "a reason" "none" "open"
expect_log "an empty log gets the header first" "$work/empty.tsv" \
  "$header" \
  "${stamp}"$'\t''frame'$'\t''began'$'\t''a reason'$'\t''none'$'\t''open'

work=$(new_directory)
trace "$work" append log.tsv $'two\tcells' $'two\nlines' $'carriage\rreturn' "plain" $'\t\n'
expect_log "a tab, a line feed or a carriage return in a cell becomes a space" "$work/log.tsv" \
  "$header" \
  "${stamp}"$'\t''two cells'$'\t''two lines'$'\t''carriage return'$'\t''plain'$'\t''  '

work=$(new_directory)
trace "$work" append log.tsv "=SUM(A1)" "+1" "-x" "@here" "a = b"
expect_log "a cell that a spreadsheet would run as a formula gets a quote in front" "$work/log.tsv" \
  "$header" \
  "${stamp}"$'\t'"'=SUM\\(A1\\)"$'\t'"'\\+1"$'\t'"'-x"$'\t'"'@here"$'\t''a = b'

work=$(new_directory)
trace "$work" append log.tsv "--help" "--" "-" "--version" "-h"
expect_log "a cell that looks like an option is written as a cell" "$work/log.tsv" \
  "$header" \
  "${stamp}"$'\t'"'--help"$'\t'"'--"$'\t'"'-"$'\t'"'--version"$'\t'"'-h"

# A file name can hold bytes that are no UTF-8, and the log keeps them as they
# came, as upstream's log.sh does.
work=$(new_directory)
trace "$work" append log.tsv frame "read export"$'\xff\xfe'".csv" "why" "evidence" "result"
row=$(tail -n 1 "$work/log.tsv" | cut -f 2-)
if ((status == 0)) && [[ "$row" == "frame"$'\t'"read export"$'\xff\xfe'".csv"$'\t'"why"$'\t'"evidence"$'\t'"result" ]]; then
  pass "a cell's bytes that are no UTF-8 are written as they came"
else
  fail "a cell's bytes that are no UTF-8 are written as they came" "got exit $status, the row '$row' and: $output"
fi

trace "$work" table log.tsv
if ((status == 0)) && [[ "$output" == *"| frame | read export"$'\xef\xbf\xbd\xef\xbf\xbd'".csv | why | evidence | result |" ]]; then
  pass "the table shows each byte that is no UTF-8 as the replacement character"
else
  fail "the table shows each byte that is no UTF-8 as the replacement character" "got exit $status and: $output"
fi

usage=$'usage: trace.py append <logfile> <phase> <decision> <why> <evidence> <result>\n       trace.py table <logfile>'

work=$(new_directory)
trace "$work" append log.tsv frame "one cell short" "why" "evidence"
expect_output "a row with a cell too few is refused with the usage" 2 "$usage"
if [[ -e "$work/log.tsv" ]]; then
  fail "a refused row writes no log" "log.tsv exists"
else
  pass "a refused row writes no log"
fi

trace "$work" append log.tsv frame decision why evidence result "one cell too many"
expect_output "a row with a cell too many is refused with the usage" 2 "$usage"

trace "$work" remove log.tsv
expect_output "a command it does not have is refused with the usage" 2 "$usage"

trace "$work"
expect_output "no command at all is refused with the usage" 2 "$usage"

# --- table -------------------------------------------------------------------

work=$(new_directory)
printf '%s\n' "$header" \
  $'2026-05-24T09:02:00Z\tframe\tcounted the work first\twanted the size\tcommit 3a9f1c2\tfound 5 things' \
  $'2026-05-24T11:15:00Z\twidget\tpicked a | b\tkeep it small\t\tpixel-diff 0' >"$work/log.tsv"
trace "$work" table log.tsv
expect_output "the log prints as a Markdown table, with a pipe in a cell escaped and an empty cell kept" 0 \
  '| ts | phase | decision | why | evidence | result |
| --- | --- | --- | --- | --- | --- |
| 2026-05-24T09:02:00Z | frame | counted the work first | wanted the size | commit 3a9f1c2 | found 5 things |
| 2026-05-24T11:15:00Z | widget | picked a \| b | keep it small |  | pixel-diff 0 |'

work=$(new_directory)
trace "$work" append log.tsv frame "began" "a reason" "none" "open"
trace "$work" table log.tsv
if ((status == 0)) && [[ "$output" =~ ^'| ts | phase | decision | why | evidence | result |'$'\n''| --- | --- | --- | --- | --- | --- |'$'\n''| '${stamp}' | frame | began | a reason | none | open |'$ ]]; then
  pass "a log that append wrote prints as a table"
else
  fail "a log that append wrote prints as a table" "got exit $status and: $output"
fi

work=$(new_directory)
printf '%s\n' "$header" $'2026-05-24T09:02:00Z\tframe\tfive cells\twhy\tevidence' >"$work/log.tsv"
trace "$work" table log.tsv
expect_output "a line that is no row of six cells stops the table" 1 "trace.py: log.tsv:2: has 5 cells, a row has 6"

work=$(new_directory)
printf '%s\n' $'2026-05-24T09:02:00Z\tframe\tno header\twhy\tevidence\tresult' >"$work/log.tsv"
trace "$work" table log.tsv
expect_output "a log without the header stops the table" 1 "trace.py: log.tsv:1: the header is not ts phase decision why evidence result"

work=$(new_directory)
trace "$work" table log.tsv
expect_output "a log that does not exist stops the table" 1 "trace.py: log.tsv: no such log"

if ((failures > 0)); then
  echo "test-work-trace: $failures failure(s)" >&2
  exit 1
fi
echo "test-work-trace: ok"
