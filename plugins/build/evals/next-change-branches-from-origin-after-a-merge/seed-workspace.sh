#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
orders=$case_dir/../pull-request-says-it-met-nothing
forge=.git/forge
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0
export GIT_AUTHOR_NAME="Ada Lovelace" GIT_AUTHOR_EMAIL=ada@example.com GIT_AUTHOR_DATE="2026-11-02T09:00:00Z"
export GIT_COMMITTER_NAME="Ada Lovelace" GIT_COMMITTER_EMAIL=ada@example.com GIT_COMMITTER_DATE="2026-11-02T09:00:00Z"

cp -R "$orders/workspace/." .
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat(orders): price the lines of an order"
git init -q --bare -b main "$forge/origin.git"
git remote add origin "$PWD/$forge/origin.git"
git push -q -u origin main
git remote set-head origin main
git switch -q -c feat/reject-negative-quantity
cp -R "$orders/branch/." .
git add -A
git commit -q -m "feat(pricing): reject a negative quantity"
git push -q -u origin feat/reject-negative-quantity

git clone -q "$forge/origin.git" "$forge/github"
git -C "$forge/github" merge -q --squash origin/feat/reject-negative-quantity >/dev/null
git -C "$forge/github" commit -q -m "feat(pricing): reject a negative quantity (#1)"
cat >>"$forge/github/README.md" <<'EOF'

## Releasing

Every merge to main is a release of the order service.
EOF
git -C "$forge/github" commit -q -a -m "docs(readme): say that every merge to main is a release (#2)"
git -C "$forge/github" push -q origin main
git -C "$forge/github" push -q origin --delete feat/reject-negative-quantity
rm -rf "$forge/github"
