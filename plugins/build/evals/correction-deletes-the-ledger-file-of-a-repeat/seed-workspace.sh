#!/usr/bin/env bash
# Seed the run's empty working directory with the tree of the case
# correction-turns-a-repeat-into-a-check, as a git repository with one commit,
# and date the earlier print call 40 days back and the migration 100 days
# back. The prune script then leaves both ledger files alone on any day of the
# run, so only the skill's rule for a repeat deletes the print call's.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../correction-turns-a-repeat-into-a-check/workspace/." .
redate() {
  local ledger_file=docs/mistakes/$1 recent
  recent=$(date -d "$3" +%F)
  sed -i "s/^- \*\*Date\*\*: $2\$/- **Date**: $recent/" "$ledger_file"
  # Fails the run when the shared tree no longer holds the date this replaces.
  grep -q "^- \*\*Date\*\*: $recent\$" "$ledger_file"
}
redate a-print-call-was-left-in-library-code.md 2025-06-17 '40 days ago'
redate a-migration-was-edited-after-it-ran.md 2026-08-19 '100 days ago'
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
