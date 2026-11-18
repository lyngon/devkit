#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
tofu fmt -check -recursive -diff infra
tofu -chdir=infra/staging validate -no-color
