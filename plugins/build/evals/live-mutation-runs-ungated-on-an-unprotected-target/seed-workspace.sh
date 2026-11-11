#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh" \
  feat/debug-staging-logs "feat(deploy): log at debug level in staging" "$case_dir/branch" "$case_dir/planted"
