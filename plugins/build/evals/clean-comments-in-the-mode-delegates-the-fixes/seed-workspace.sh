#!/usr/bin/env bash
set -euo pipefail

case_directory=$(dirname "${BASH_SOURCE[0]}")
cp -R "$case_directory/../architect-stops-at-the-design-gate/workspace/." .
printf '__pycache__/\n' >.gitignore
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
git switch -q -c feat/rate-cache
cp -R "$case_directory/../clean-comments-keeps-only-the-exceptions/workspace/." .
cp -R "$case_directory/workspace/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(rates): cache each rate for ten minutes"
