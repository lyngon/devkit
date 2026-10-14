#!/usr/bin/env bash
# Seed the run's empty working directory as the case finish-says-it-met-nothing
# does, with the files under planted/ on main: a refund that drops the
# currency, which the full check shows as a skipped test.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$case_dir/../finish-says-it-met-nothing/seed-workspace.sh" "$case_dir/planted"
