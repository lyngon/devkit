#!/usr/bin/env bash
# Seed the run's empty working directory as a git repository: the tree that
# the case architect-stops-at-the-design-gate keeps under workspace/ on main,
# and the branch feat/rate-cache with one commit that adds the files of this
# case's workspace/.
set -euo pipefail

case_directory=$(dirname "${BASH_SOURCE[0]}")
cp -R "$case_directory/../architect-stops-at-the-design-gate/workspace/." .
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
git switch -q -c feat/rate-cache
cp -R "$case_directory/workspace/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(rates): cache each rate for ten minutes"
