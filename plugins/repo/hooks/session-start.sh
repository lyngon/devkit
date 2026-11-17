#!/usr/bin/env bash
# SessionStart hook of the repo plugin: its standard output is added to the
# session context.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

# The line as repo:init writes it; a comment or `= false` does not match.
if grep -qsE '^[[:space:]]*lyngon\.structure\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$root/devenv.nix"; then
  cat "$here/session-start-structure.txt"
fi

add_line_atomically() {
  local file=$1 line=$2 content="" temporary
  [[ ! -f $file ]] || content=$(<"$file")
  temporary=$(mktemp "$file.XXXXXX")
  printf '%s\n' ${content:+"$content"} "$line" >"$temporary"
  mv "$temporary" "$file"
}

ignore_session_worktrees() {
  local top exclude code=0
  top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || return 0
  git -C "$top" check-ignore -q --no-index .claude/worktrees/ || code=$?
  ((code == 1)) || return 0
  exclude=$(git -C "$top" rev-parse --path-format=absolute --git-path info/exclude)
  mkdir -p "${exclude%/*}"
  add_line_atomically "$exclude" /.claude/worktrees/
}
ignore_session_worktrees

commits() {
  if (($1 == 1)); then echo "1 commit"; else echo "$1 commits"; fi
}

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

if [[ -n "$default" && "$local_default" != "$branch" ]] &&
  behind=$(git -C "$root" rev-list --count "refs/heads/$local_default..refs/remotes/$default" 2>/dev/null) && ((behind > 0)); then
  echo "The local $local_default is $(commits "$behind") behind $default. Start every new branch from $default, not from $local_default."
fi

# fetch_seconds and sweep_seconds together stay under the hook's timeout in
# hooks.json, however long the branch tests take. A branch left untested waits
# for a later session start.
sweep_seconds=5

in_time() {
  local seconds=$((deadline - SECONDS))
  ((seconds > 0)) && timeout "$seconds" git -C "$root" "$@"
}

# A branch has nothing new when merging it changes nothing, or when a squash of
# it has the patch-id of a commit of the default branch since the merge base,
# as when a later change on the default branch conflicts with its squash merge.
has_nothing_new() {
  local tip=$1 tree base squash
  if tree=$(in_time merge-tree --write-tree --no-messages "$default_ref" "$tip" 2>/dev/null) && [[ $tree == "$default_tree" ]]; then
    return 0
  fi
  base=$(in_time merge-base "$default_ref" "$tip") || return 1
  # Fixed fields make the squash one object, however many sessions start.
  squash=$(GIT_AUTHOR_NAME=squash GIT_AUTHOR_EMAIL=squash GIT_AUTHOR_DATE='@0 +0000' \
    GIT_COMMITTER_NAME=squash GIT_COMMITTER_EMAIL=squash GIT_COMMITTER_DATE='@0 +0000' \
    in_time commit-tree -p "$base" -m squash "$tip^{tree}") || return 1
  [[ $(in_time cherry "$default_ref" "$squash") == "- $squash" ]]
}

delete_branches_with_nothing_new() {
  local branch tip deleted=() list key path
  local -A worktree_names=()
  while read -r key path; do
    [[ $key != worktree ]] || worktree_names[${path##*/}]=1
  done < <(git -C "$root" worktree list --porcelain)
  while read -r branch tip; do
    ((SECONDS < deadline)) || break
    [[ $branch != "$local_default" ]] || continue
    # Claude Code starts the worktree <name> on the branch worktree-<name>, and
    # without that branch its ExitWorktree cannot count the session's commits.
    [[ $branch != worktree-* || -z ${worktree_names[${branch#worktree-}]-} ]] || continue
    has_nothing_new "$tip" || continue
    # git refuses a branch that any worktree has checked out, rebases or bisects.
    git -C "$root" branch --quiet --delete --force "$branch" 2>/dev/null || continue
    deleted+=("$branch at $tip")
  done < <(git -C "$root" for-each-ref --format='%(refname:lstrip=2) %(objectname)' refs/heads)
  ((${#deleted[@]} > 0)) || return 0
  list=$(printf ', %s' "${deleted[@]}")
  echo "Deleted the local branches whose changes are already in $default: ${list#, }. To restore one, run \`git branch <branch> <commit>\`."
}

default_ref=refs/remotes/$default
if [[ -n "$default" ]] && default_tree=$(git -C "$root" rev-parse --verify --quiet "$default_ref^{tree}"); then
  deadline=$((SECONDS + sweep_seconds))
  delete_branches_with_nothing_new
fi
