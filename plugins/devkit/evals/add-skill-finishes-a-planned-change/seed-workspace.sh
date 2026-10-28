#!/usr/bin/env bash
# Seed the run's empty working directory with a small stand-in for the Lyngon
# devkit: main holds the tree under workspace/, and from this checkout the two
# catalog templates and the skill writing:simpler with its eval case, so that
# the stand-in shows a case to follow. main is checked out. The design file
# under docs/plans/ has the change that the case's prompt names.
#
# Nothing in the run reaches a network. The upstream acme/brevity is a git
# repository at tmp/forge/acme-brevity, made from upstream/, where git ignores
# it; under .git/ the harness would refuse a command that copies from it. The
# forge is the
# stand-in for GitHub of the cases of build:finish: the remote is a bare
# repository under .git/forge, and their gh records the pull requests there.
# The case puts .git/forge/bin in front of the PATH, which also holds a devenv
# whose `devenv test` runs scripts/check.sh, and a claude and a compare-evals
# that refuse to start an eval run.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../../.." && pwd)
forge=.git/forge

cp -R "$case_dir/workspace/." .
mkdir -p catalog/vendored
cp "$root/catalog/TEMPLATE.md" catalog/TEMPLATE.md
cp "$root/catalog/vendored/TEMPLATE.md" catalog/vendored/TEMPLATE.md
mkdir -p plugins/writing/skills plugins/writing/evals
cp -R "$root/plugins/writing/skills/simpler" plugins/writing/skills/
cp -R "$root/plugins/writing/evals/simpler-restates-in-plain-words" plugins/writing/evals/
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat(writing): add simpler skill"

mkdir -p "$forge/bin"
cp "$root/plugins/build/evals/finish-says-it-met-nothing/forge/gh" "$forge/bin/gh"
cp "$case_dir/forge/devenv" "$forge/bin/devenv"
cp "$case_dir/forge/no-eval-runs" "$forge/bin/claude"
cp "$case_dir/forge/no-eval-runs" "$forge/bin/compare-evals"
chmod +x "$forge/bin/"*
git init -q --bare "$forge/origin.git"
git remote add origin "$PWD/$forge/origin.git"
git push -q origin main
git remote set-head origin main

upstream=tmp/forge/acme-brevity
mkdir -p "$upstream"
cp -R "$case_dir/upstream/." "$upstream"
git -C "$upstream" init -q -b main
git -C "$upstream" add -A
git -C "$upstream" -c user.name=Acme -c user.email=dev@acme.example commit -q -m "feat: add concise-replies"
