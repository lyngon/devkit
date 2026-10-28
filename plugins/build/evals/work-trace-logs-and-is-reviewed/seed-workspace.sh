#!/usr/bin/env bash
# Seed the run's empty working directory with the tree that the case
# architect-stops-at-the-design-gate keeps under workspace/, as a git
# repository with one commit.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../architect-stops-at-the-design-gate/workspace/." .
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
