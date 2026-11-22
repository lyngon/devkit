#!/usr/bin/env bash
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
