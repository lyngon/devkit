#!/usr/bin/env bash
# Seed the run's empty working directory with the tree under workspace/.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/workspace/." .
