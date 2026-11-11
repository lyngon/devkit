#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$case_dir/../pull-request-says-it-met-nothing/seed-workspace.sh"
cp "$case_dir/forge/state.json" .git/forge/state.json
