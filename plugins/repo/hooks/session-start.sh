#!/usr/bin/env bash
# SessionStart hook of the repo plugin: prints session-start-structure.txt,
# which is added to the session context, when the root CLAUDE.md says the
# repository follows the Lyngon structure, and prints nothing otherwise. The
# lines about which devkit skills to invoke come from the conventions plugin's
# own hook.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

grep -qsF "This repository follows the Lyngon structure" "$root/CLAUDE.md" || exit 0

cat "$here/session-start-structure.txt"
