#!/usr/bin/env bash
# Seed the run's empty working directory with the tree of the case
# correction-turns-a-repeat-into-a-check, as a git repository with one commit,
# and date the earlier print call 40 days back. The prune script then leaves
# its ledger file alone, so only the skill's rule for a repeat deletes it.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/../correction-turns-a-repeat-into-a-check/workspace/." .
ledger_file=docs/mistakes/a-print-call-was-left-in-library-code.md
recent=$(date -d '40 days ago' +%F)
sed -i "s/^- \*\*Date\*\*: 2025-06-17\$/- **Date**: $recent/" "$ledger_file"
# Fails the run when the shared tree no longer holds the date this replaces.
grep -q "^- \*\*Date\*\*: $recent\$" "$ledger_file"
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
