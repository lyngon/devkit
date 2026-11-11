#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh"
session=$(grep -m 1 -o '"sessionId":"[^"]*"' "$case_dir/history.jsonl" | cut -d '"' -f 4)
mkdir -p "tmp/live-mutation/$session"
cp -R "$case_dir/proposal/." "tmp/live-mutation/$session/"
