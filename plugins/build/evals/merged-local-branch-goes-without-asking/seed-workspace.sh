#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0

"$case_dir/../next-change-branches-from-origin-after-a-merge/seed-workspace.sh"
# Left at an older commit of main, as a subagent's worktree branch is once
# Claude Code has removed the worktree.
git branch worktree-agent-left-behind main
# A deleted branch then leaves its line in packed-refs, which the graders read.
git pack-refs --all
