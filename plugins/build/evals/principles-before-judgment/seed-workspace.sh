#!/usr/bin/env bash
# Seed the run's empty working directory as the case
# architect-stops-at-the-design-gate does: the rates package, one commit on main.
set -euo pipefail

bash "$(dirname "${BASH_SOURCE[0]}")/../architect-stops-at-the-design-gate/seed-workspace.sh"
