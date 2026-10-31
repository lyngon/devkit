#!/usr/bin/env bash
# Seed the run's empty working directory as the case
# pull-request-says-it-met-nothing does, with a gh in front of the PATH that is
# not signed in, so that the forge has no tool the run can use.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../pull-request-says-it-met-nothing/seed-workspace.sh"
cp "$case_dir/forge/gh" .git/forge/bin/gh
chmod +x .git/forge/bin/gh
