#!/usr/bin/env bash
set -euo pipefail

tree=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && pwd -P)
while [[ -n $tree ]] && ! [[ -e $tree/.git && -f $tree/devenv.nix ]]; do
  tree=${tree%/*}
done
[[ -n $tree ]] || exit 0

missing=()
effects=()
if ! command -v python3 >/dev/null; then
  missing+=(python3)
  effects+=("No Python hook of a plugin runs, and Claude Code goes on as if it did not exist, the build plugin's guard on OpenTofu commands that write included.")
fi
if ! command -v shfmt >/dev/null; then
  missing+=(shfmt)
  ((${#effects[@]} > 0)) || effects+=("No hook can parse a shell command without shfmt, so the build plugin's guard on OpenTofu commands refuses each one that names tofu.")
fi
if ! command -v pygmentize >/dev/null; then
  missing+=(pygmentize)
  [[ ${missing[0]} == python3 ]] || effects+=("No hook can tell comments from code without pygmentize, so the build plugin's guard on the comment auditor refuses each edit it makes inside a repository.")
fi
((${#missing[@]} > 0)) || exit 0

case ${#missing[@]} in
  1) names="${missing[0]} is" ;;
  2) names="${missing[0]} and ${missing[1]} are" ;;
  *) names="${missing[0]}, ${missing[1]} and ${missing[2]} are" ;;
esac
effect=${effects[*]}
cause="$names missing from the PATH that Claude Code gives its hooks. That is the PATH the session started with, which lacks the repository's devenv environment, and the environment that Bash commands get never reaches a hook."
remedy="A session started from a shell where the repository's devenv environment is loaded runs them. In VS Code, close the window and open the repository with code . from such a shell, because the Claude Code extension keeps the first PATH it reads in a window."

printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
  "$cause $effect $remedy" \
  "$cause $effect Tell the operator in your first reply. $remedy"
