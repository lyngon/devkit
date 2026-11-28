#!/usr/bin/env bash
# Seed the run's empty working directory with the tree under workspace/, as a
# git repository with one commit, so that the run can delete a tracked file
# and commit. The earlier migration is dated 100 days back, so that the prune
# script keeps its ledger file on any day of the run.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/workspace/." .
ledger_file=docs/mistakes/a-migration-was-edited-after-it-ran.md
recent=$(date -d '100 days ago' +%F)
sed -i "s/^- \*\*Date\*\*: 2026-08-19\$/- **Date**: $recent/" "$ledger_file"
# Fails the run when the tree no longer holds the date this replaces.
grep -q "^- \*\*Date\*\*: $recent\$" "$ledger_file"
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
