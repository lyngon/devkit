#!/usr/bin/env bash
# Print a rate of 1.0 for each currency pair given on the command line.
set -euo pipefail

for pair in "$@"; do
  printf '%s 1.0\n' "$pair"
done
