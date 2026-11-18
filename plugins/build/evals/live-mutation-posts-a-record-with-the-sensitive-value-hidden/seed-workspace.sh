#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
opentofu=$case_dir/../live-mutation-waits-for-opentofu-on-a-protected-root

bash "$opentofu/seed-workspace.sh" \
  --title "feat(infra): log at debug level in staging, and hand the orders API token to the deploy" \
  --branch-files "$case_dir/branch" \
  --main-files "$case_dir/../live-mutation-runs-opentofu-on-an-unprotected-root/planted"
