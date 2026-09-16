#!/usr/bin/env bash
# Flag the typographic marks that identify prose as machine-written: em and
# en dashes and curly quotes. Runs on Markdown files at pre-commit and, with
# --commit-msg, on the commit message at commit-msg. This is the deterministic
# half of the job; the judgment half is the writing plugin's unslop skill.
set -euo pipefail

mode=files
if [[ "${1:-}" == "--commit-msg" ]]; then
  mode=commit-msg
  shift
fi

# The marks are spelled as UTF-8 bytes and matched under LC_ALL=C, so the
# result does not depend on the locale and the script itself stays ASCII.
export LC_ALL=C

marks=(
  $'\xe2\x80\x94|em dash (U+2014): use a comma, a period or parentheses'
  $'\xe2\x80\x93|en dash (U+2013): use a hyphen or the word "to"'
  $'\xe2\x80\x9c|curly double quote (U+201C): use a straight double quote'
  $'\xe2\x80\x9d|curly double quote (U+201D): use a straight double quote'
  $'\xe2\x80\x98|curly single quote (U+2018): use a straight single quote'
  $'\xe2\x80\x99|curly single quote (U+2019): use a straight single quote'
)

status=0
for file in "$@"; do
  if [[ "$mode" == commit-msg ]]; then
    # Blank comment lines and stop at the scissors line (git commit -v), keeping line numbers.
    content=$(awk '/^# -+ >8 -+$/ { exit } /^#/ { print ""; next } { print }' "$file")
  else
    content=$(cat "$file")
  fi
  for mark in "${marks[@]}"; do
    char=${mark%%|*}
    message=${mark#*|}
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      echo "$file:$line: $message" >&2
      status=1
    done < <(grep -n -F -- "$char" <<<"$content" | cut -d: -f1 || true)
  done
done

if ((status != 0)); then
  echo "prose-lint: replace the marks above by hand, or run /writing:unslop on the text" >&2
fi
exit "$status"
