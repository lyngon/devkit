#!/usr/bin/env bash
# Seed the run's empty working directory with the repository acme/orders, the
# tree under workspace/, as a git repository with one commit on main and no
# remote. Its pricing gives a line of exactly 10 items no bulk discount, which
# the README promises from 10 items on.
set -euo pipefail

cp -R "$(dirname "${BASH_SOURCE[0]}")/workspace/." .
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(orders): price the lines of an order"
