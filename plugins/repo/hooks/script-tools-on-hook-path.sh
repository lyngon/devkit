#!/usr/bin/env bash
# SessionStart hook of the repo plugin. It says so when a tool that the
# plugins' hooks run is missing from the PATH that Claude Code gives every
# hook, and so it runs on bash alone.
set -euo pipefail

tree=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && pwd -P)
while [[ -n $tree ]] && ! [[ -e $tree/.git && -f $tree/devenv.nix ]]; do
  tree=${tree%/*}
done
[[ -n $tree ]] || exit 0

if ! command -v python3 >/dev/null; then
  effect="No Python hook of a plugin runs, and Claude Code goes on as if it did not exist, the build plugin's guard on OpenTofu commands that write included."
  if command -v shfmt >/dev/null; then names="python3 is"; else names="python3 and shfmt are"; fi
elif ! command -v shfmt >/dev/null; then
  effect="A hook that parses a shell command with shfmt cannot, so the build plugin's guard on OpenTofu commands refuses each one that names tofu."
  names="shfmt is"
else
  exit 0
fi
cause="$names missing from the PATH that Claude Code gives its hooks, because this session started without the repository's devenv environment, and the environment that Bash commands get never reaches a hook."
remedy="A session started from the repository's devenv shell runs them."

printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
  "$cause $effect $remedy" \
  "$cause $effect Tell the operator in your first reply. $remedy"
