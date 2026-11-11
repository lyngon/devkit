#!/usr/bin/env bash
# The intent and the agent file are written here and not kept under workspace/:
# tracked in the devkit, the agent file would load into a devkit session that
# reads a file of this case.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/workspace/." .
mkdir -p .claude
printf '%s\n' "@../INTENT.md" >.claude/CLAUDE.md
cat >INTENT.md <<'INTENT'
# Intent

What this repository is for, for whom, and what done means.
It changes when the purpose changes, not when the plan changes.

## Product

**Tidewatch** predicts the height of the water in each harbour it knows, minute by minute, for the pilots who bring ships in.

## For whom

- Repository: the Tidewatch team.
- Artifacts: harbour pilots and the scheduling system of the port authority.

## Done means

- Every prediction for the next 48 hours lies within 10 centimetres of the height measured at the harbour.
- A new harbour goes live from its tidal constituents alone, without a change to the code.

## Failure means

- A pilot trusts a prediction that is off by more than 10 centimetres.

## Non-goals

- Weather, waves and currents.

## Horizon

Years. Pilots plan every arrival on it.
INTENT
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
git switch -q -c feat/check-tide-tables
