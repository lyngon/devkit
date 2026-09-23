#!/usr/bin/env bash
# SessionStart hook of the repo plugin: adds the text of session-start.txt to
# the session context, plus session-start-structure.txt when the root
# CLAUDE.md says the repository follows the Lyngon structure. The text stays
# short on purpose; it says which skills to invoke and when, which is the one
# thing agents do not do unprompted.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

files=("$here/session-start.txt")
if grep -qsF "This repository follows the Lyngon structure" "$root/CLAUDE.md"; then
  files+=("$here/session-start-structure.txt")
fi

text=""
for file in "${files[@]}"; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//\\/\\\\}
    line=${line//\"/\\\"}
    text+="$line\\n"
  done <"$file"
done

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
