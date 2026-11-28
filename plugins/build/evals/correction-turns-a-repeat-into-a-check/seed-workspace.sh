#!/usr/bin/env bash
# Seed the run's empty working directory with the tree under workspace/, as a
# git repository with one commit, so that the run can delete a tracked file
# and commit.
set -euo pipefail

here=$(dirname "${BASH_SOURCE[0]}")
cp -R "$here/workspace/." .
bash "$here/date-back.sh" a-migration-was-edited-after-it-ran.md 2026-08-19 '100 days ago'
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
