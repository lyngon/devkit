#!/usr/bin/env bash
# Seed the run's empty working directory as the case pull-request-says-it-met-nothing
# does, and give the stand-in forge the open issue #64 that the branch fixes.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$case_dir/../pull-request-says-it-met-nothing/seed-workspace.sh"
cp "$case_dir/forge/state.json" .git/forge/state.json
