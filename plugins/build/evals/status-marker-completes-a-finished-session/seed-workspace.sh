#!/usr/bin/env bash
# Seed the run's empty working directory with a repository whose one commit is
# on its remote: main is pushed to a bare origin under .git/forge, and nothing
# is left to commit. Without a repository of its own the working directory lies
# in the one that the sandbox writes into the run's home, whose untracked files
# would keep the session from being complete.
set -euo pipefail

printf '# photo-dates\n\nA command-line tool for a folder of photos.\n' >README.md
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add README.md
git commit -q -m "docs: describe photo-dates"
git init -q --bare .git/forge/origin.git
git remote add origin "$PWD/.git/forge/origin.git"
git push -q -u origin main
