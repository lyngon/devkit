#!/usr/bin/env bash
# Seed the run's empty working directory with the repository acme/orders:
# main holds the tree under workspace/, and the files under branch/ are the
# one commit of feat/reject-negative-quantity, which is checked out. A
# directory given as the one argument is copied over workspace/ before the
# commit of main, so that a case can put on main a problem for the run to meet.
#
# The forge is a stand-in for GitHub: the remote is a bare repository under
# .git/forge, and forge/gh, which the case puts in front of the PATH, records
# the issues and pull requests in .git/forge.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
forge=.git/forge

cp -R "$case_dir/workspace/." .
if (($# > 0)); then
  cp -R "$1/." .
fi
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat(orders): price the lines of an order"
git switch -q -c feat/reject-negative-quantity
cp -R "$case_dir/branch/." .
git add -A
git commit -q -m "feat(pricing): reject a negative quantity"

mkdir -p "$forge/bin"
cp "$case_dir/forge/gh" "$forge/bin/gh"
chmod +x "$forge/bin/gh"
git init -q --bare "$forge/origin.git"
git remote add origin "$PWD/$forge/origin.git"
git push -q origin main
git remote set-head origin main
