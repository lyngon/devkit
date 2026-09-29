#!/usr/bin/env bash
# SessionStart hook of the repo plugin: adds the text of
# session-start-structure.txt to the session context when the root CLAUDE.md
# says the repository follows the Lyngon structure, and prints nothing
# otherwise. The lines about which devkit skills to invoke come from the
# conventions plugin's own hook.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

grep -qsF "This repository follows the Lyngon structure" "$root/CLAUDE.md" || exit 0

text=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line//\\/\\\\}
  line=${line//\"/\\\"}
  text+="$line\\n"
done <"$here/session-start-structure.txt"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
