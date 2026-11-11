#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
branch=${1:-feat/longer-log-retention}
title=${2:-"feat(deploy): keep the logs of the orders service for 90 days"}
branch_files=${3:-$here/branch}
forge=.git/forge

export GIT_AUTHOR_NAME="Ada Lovelace" GIT_AUTHOR_EMAIL=ada@example.com GIT_AUTHOR_DATE=2026-11-10T09:00:00Z
export GIT_COMMITTER_NAME="Ada Lovelace" GIT_COMMITTER_EMAIL=ada@example.com GIT_COMMITTER_DATE=2026-11-10T09:00:00Z
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0

cp -R "$here/workspace/." .
if (($# > 3)); then
  cp -R "$4/." .
fi
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat(deploy): describe the cloud resources of the orders service"

mkdir -p "$forge/bin" "$forge/cloud"
cp "$here/../pull-request-says-it-met-nothing/forge/gh" "$forge/bin/gh"
cp "$here/cloud/cloudctl" "$forge/bin/cloudctl"
cp "$here/cloud/production.json" "$here/cloud/staging.json" "$forge/cloud/"
chmod +x "$forge/bin/gh" "$forge/bin/cloudctl"
git init -q --bare "$forge/origin.git"
git remote add origin "$PWD/$forge/origin.git"
git push -q origin main
git remote set-head origin main

git switch -q -c "$branch"
cp -R "$branch_files/." .
git add -A
git commit -q -m "$title"
git push -q -u origin "$branch"
"$forge/bin/gh" pr create --title "$title" --body "Changes deploy/ only. Live state follows when the change is applied." >/dev/null
