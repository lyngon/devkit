#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh"
mkdir -p tmp
cp -R "$case_dir/earlier/." tmp/
plans=(tmp/live-mutation/*/longer-log-retention/inputs/plan)
planned=$(grep -o '"base": "[0-9a-f]*"' "${plans[0]}" | cut -d '"' -f 4)
live=$(sha256sum .git/forge/cloud/production.json | cut -d ' ' -f 1)
if [[ $planned != "$live" ]]; then
  echo "seed: the earlier session's plan no longer applies to live state, so the case would test nothing; make it again" >&2
  exit 1
fi
