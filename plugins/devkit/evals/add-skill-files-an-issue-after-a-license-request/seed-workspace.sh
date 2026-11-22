#!/usr/bin/env bash
# Seed the run's empty working directory with the stand-in for the Lyngon
# devkit that the case add-skill-finishes-a-planned-change keeps, without its
# design file. main is checked out.
#
# Nothing in the run reaches a network. The upstream acme/brevity is a git
# repository at tmp/forge/acme-brevity, made from that case's upstream/
# without its LICENSE, so that the skill has no license. The case puts
# .git/forge/bin in front of the PATH, which holds a gh that keeps the issues
# it is given under .git/forge/, where the graders read them.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../../.." && pwd)
planned=$case_dir/../add-skill-finishes-a-planned-change
forge=.git/forge

cp -R "$planned/workspace/." .
rm -r docs/plans
mkdir -p catalog/vendored
cp "$root/catalog/TEMPLATE.md" catalog/TEMPLATE.md
cp "$root/catalog/vendored/TEMPLATE.md" catalog/vendored/TEMPLATE.md
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat: start the marketplace"

mkdir -p "$forge/bin"
cp "$root/plugins/build/evals/pull-request-says-it-met-nothing/forge/gh" "$forge/bin/gh"
chmod +x "$forge/bin/gh"
echo lyngon/devkit >"$forge/repository"

upstream=tmp/forge/acme-brevity
mkdir -p "$upstream"
cp -R "$planned/upstream/." "$upstream"
rm "$upstream/LICENSE"
git -C "$upstream" init -q -b main
git -C "$upstream" add -A
git -C "$upstream" -c user.name=Acme -c user.email=dev@acme.example commit -q -m "feat: add concise-replies"
