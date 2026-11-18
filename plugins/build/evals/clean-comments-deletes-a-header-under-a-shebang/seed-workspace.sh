#!/usr/bin/env bash
set -euo pipefail

case_directory=$(dirname "${BASH_SOURCE[0]}")
bash "$case_directory/../architect-stops-at-the-design-gate/seed-workspace.sh"
git switch -q -c feat/rate-script
cp -R "$case_directory/workspace/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(rates): print a rate for each pair given"
