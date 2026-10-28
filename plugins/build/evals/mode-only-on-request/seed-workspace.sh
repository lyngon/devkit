#!/usr/bin/env bash
# Seed the run's empty working directory with the tree that the case
# architect-stops-at-the-design-gate keeps under workspace/.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../architect-stops-at-the-design-gate/workspace/." .
