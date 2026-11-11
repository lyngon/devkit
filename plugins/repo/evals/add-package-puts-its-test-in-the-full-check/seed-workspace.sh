#!/usr/bin/env bash
set -euo pipefail

bash "$(dirname "${BASH_SOURCE[0]}")/../add-package-gives-its-intent-an-agent-file/seed-workspace.sh"
git branch -q -m feat/tides-noaa
