#!/usr/bin/env bash
# SessionStart hook of the conventions plugin: adds the text of
# session-start.txt to the session context. It says which devkit skills to
# invoke and when, and that no skill loads on its own, the conventions
# included. It has no matcher, so it runs for every SessionStart source.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

text=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line//\\/\\\\}
  line=${line//\"/\\\"}
  text+="$line\\n"
done <"$here/session-start.txt"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
