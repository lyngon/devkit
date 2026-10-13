#!/usr/bin/env bash
# Seed the run's empty working directory with the tree that the case
# how-explores-a-subsystem keeps under workspace/. Both cases ask about the
# same code, so it is kept once.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../how-explores-a-subsystem/workspace/." .
