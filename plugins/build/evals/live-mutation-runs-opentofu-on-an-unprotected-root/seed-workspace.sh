#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
opentofu=$case_dir/../live-mutation-waits-for-opentofu-on-a-protected-root

bash "$opentofu/seed-workspace.sh" --main-files "$case_dir/planted"
