#!/usr/bin/env bash
# Seed the run's empty working directory with a repository that has one commit
# on main and no remote, so that a commit of the run exists only there.
set -euo pipefail

printf '# photo-dates\n\nA command-line tool for a folder of photos.\n' >README.md
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add README.md
git commit -q -m "docs: describe photo-dates"
