#!/usr/bin/env bash
# The full check of the repository: every OpenTofu root formatted and valid, without reading live state.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
tofu fmt -check -recursive -diff infra
tofu -chdir=infra/staging validate -no-color
