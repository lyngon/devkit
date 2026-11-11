#!/usr/bin/env bash
# SessionStart hook of the repo plugin: its standard output is added to the
# session context. It prints session-start-structure.txt when the root
# devenv.nix sets lyngon.structure.enable = true, the one marker of a
# repository that follows the Lyngon structure. It then fetches origin and
# adds a line when the fetch fails, when the current branch is behind its
# upstream or its upstream no longer exists, and when the local default
# branch is behind origin's; otherwise nothing. The lines about which devkit
# skills to invoke come from the conventions plugin's own hook.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

# The line as repo:init writes it; a comment or `= false` does not match.
if grep -qsE '^[[:space:]]*lyngon\.structure\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$root/devenv.nix"; then
  cat "$here/session-start-structure.txt"
fi

commits() {
  if (($1 == 1)); then echo "1 commit"; else echo "$1 commits"; fi
}

# Stays under the hook's timeout in hooks.json, so that a remote that never
# answers still leaves the hook time to say so.
fetch_seconds=10
if git -C "$root" remote get-url origin >/dev/null 2>&1; then
  code=0
  error=$(GIT_TERMINAL_PROMPT=0 timeout "$fetch_seconds" git -C "$root" fetch --quiet --prune origin 2>&1) || code=$?
  if ((code != 0)); then
    reason=${error%%$'\n'*}
    if ((code == 124)); then reason="no answer within $fetch_seconds s"; fi
    echo "Could not fetch origin at session start ($reason), so what this session knows of origin dates from the last fetch. Before you start a branch, fetch again. If that fetch fails too, say so."
  fi
fi

branch=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=
default=$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || default=
local_default=${default#origin/}

if [[ -n "$branch" ]]; then
  tracking=$(git -C "$root" for-each-ref --format='%(upstream:short) %(upstream:track,nobracket)' "refs/heads/$branch")
  upstream=${tracking%% *}
  track=${tracking#* }
  if [[ "$track" == gone ]]; then
    echo "The current branch, $branch, tracks $upstream, which no longer exists, as when a pull request merges and GitHub deletes its branch. Before you work on $branch again, check whether its pull request merged. Start new work on a new branch from ${default:-the default branch of origin}."
  elif [[ "$track" =~ behind\ ([0-9]+) ]]; then
    echo "The current branch is $(commits "${BASH_REMATCH[1]}") behind its upstream; fast-forward before starting: \`git pull --ff-only\`."
  fi
fi

# When the default branch is the current one, the line above covers it.
if [[ -n "$default" && "$local_default" != "$branch" ]] &&
  behind=$(git -C "$root" rev-list --count "refs/heads/$local_default..refs/remotes/$default" 2>/dev/null) && ((behind > 0)); then
  echo "The local $local_default is $(commits "$behind") behind $default. Start every new branch from $default, not from $local_default."
fi
