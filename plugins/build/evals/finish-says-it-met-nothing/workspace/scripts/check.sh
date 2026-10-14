#!/usr/bin/env bash
# The full check of the repository: every test, each with its verdict.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
PYTHONPATH=src python3 -m unittest discover --start-directory tests --verbose
