#!/usr/bin/env bash
set -euo pipefail

printf '# photo-dates\n\nA command-line tool for a folder of photos.\n' >README.md
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add README.md
git commit -q -m "docs: describe photo-dates"
