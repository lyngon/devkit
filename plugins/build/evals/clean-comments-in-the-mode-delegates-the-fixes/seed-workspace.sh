#!/usr/bin/env bash
# Seed the run's empty working directory as the repository of the case
# clean-comments-keeps-only-the-exceptions, on the branch feat/rate-cache,
# with the cache.py of this case's workspace/ in its one commit against main.
# That cache.py keeps a path that never runs and a comment that excuses it,
# so the comment auditor has a trivial fix to flag. Main ignores the bytecode
# that the full check writes, so that cleaning it up is no write of the lead.
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
