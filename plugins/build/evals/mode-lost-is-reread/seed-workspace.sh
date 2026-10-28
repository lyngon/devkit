#!/usr/bin/env bash
# Seed the run's empty working directory with the repository as the session in
# history.jsonl left it: the case architect-stops-at-the-design-gate's tree on
# main, and the branch feat/rate-json-output with the one commit that the
# session made, whose files are under branch/. The session was recorded with
# Claude Code 2.1.283 from `/build:auto` with the task to add --json to
# `rates rate`, then a turn that loaded every skill the agent may start, then
# `/compact`. The skills that
# the compaction keeps are the most recent ones within its budget, and the mode
# is not among them. Only what follows the compaction boundary is kept, with
# the paths of the machine that recorded it replaced.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../architect-stops-at-the-design-gate/seed-workspace.sh"
git switch -q -c feat/rate-json-output
cp -R "$case_dir/branch/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -F - <<'EOF'
feat: add --json to the rate command
EOF
