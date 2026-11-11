#!/usr/bin/env bash
# Seed the run's empty working directory as the case
# live-mutation-runs-ungated-on-an-unprotected-target does, with the branch
# feat/drop-the-staging-archive, which removes the archive bucket of staging
# and with it the objects that the bucket holds live.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh" \
  feat/drop-the-staging-archive "feat(deploy): drop the archive bucket of staging" "$case_dir/branch" \
  "$case_dir/../live-mutation-runs-ungated-on-an-unprotected-target/planted"
