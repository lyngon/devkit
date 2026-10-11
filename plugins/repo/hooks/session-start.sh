#!/usr/bin/env bash
# SessionStart hook of the repo plugin: its standard output is added to the
# session context. It prints session-start-structure.txt when the root
# devenv.nix sets lyngon.structure.enable = true, the one marker of a
# repository that follows the Lyngon structure, and a line when the current
# branch is behind its upstream; otherwise nothing. The lines about which
# devkit skills to invoke come from the conventions plugin's own hook.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

# The line as repo:init writes it; a comment or `= false` does not match.
if grep -qsE '^[[:space:]]*lyngon\.structure\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$root/devenv.nix"; then
  cat "$here/session-start-structure.txt"
fi

# Counts what the last fetch saw; the hook does not fetch.
if behind=$(git -C "$root" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) && ((behind > 0)); then
  commits=commits
  if ((behind == 1)); then commits=commit; fi
  echo "The current branch is $behind $commits behind its upstream; fast-forward before starting: \`git pull --ff-only\`."
fi
