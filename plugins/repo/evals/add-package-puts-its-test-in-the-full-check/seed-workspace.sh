#!/usr/bin/env bash
# Seed the run's empty working directory with the repository that the case
# add-package-gives-its-intent-an-agent-file seeds, on a branch for this one.
set -euo pipefail

bash "$(dirname "${BASH_SOURCE[0]}")/../add-package-gives-its-intent-an-agent-file/seed-workspace.sh"
git branch -q -m feat/tides-noaa
