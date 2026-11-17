#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0

"$case_dir/../next-change-branches-from-origin-after-a-merge/seed-workspace.sh"
git branch worktree-agent-left-behind main
git pack-refs --all

for grader in "$case_dir"/graders/*.md; do
  ref=$(grep -o 'refs/heads/[^$]*' "$grader") || continue
  if ! grep -q " $ref\$" .git/packed-refs; then
    echo "seed-workspace.sh: $grader reads $ref in .git/packed-refs, which does not hold it" >&2
    exit 1
  fi
done
