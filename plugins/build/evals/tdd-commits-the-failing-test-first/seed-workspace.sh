#!/usr/bin/env bash
# Seed the run's empty working directory as the case bug-fix-repro-first does.
set -euo pipefail

bash "$(dirname "${BASH_SOURCE[0]}")/../bug-fix-repro-first/seed-workspace.sh"
