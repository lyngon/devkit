#!/usr/bin/env bash
# Seed the run's empty working directory with the repository of the case
# correction-writes-a-ledger-file, which this case only starts differently.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../correction-writes-a-ledger-file/workspace/." .
