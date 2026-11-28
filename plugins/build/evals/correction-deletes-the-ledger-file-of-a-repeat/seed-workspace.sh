#!/usr/bin/env bash
set -euo pipefail

tree=$(dirname "${BASH_SOURCE[0]}")/../correction-turns-a-repeat-into-a-check
cp -R "$tree/workspace/." .
bash "$tree/date-back.sh" a-print-call-was-left-in-library-code.md 2025-06-17 '40 days ago'
bash "$tree/date-back.sh" a-migration-was-edited-after-it-ran.md 2026-08-19 '100 days ago'
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
