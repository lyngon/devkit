#!/usr/bin/env bash
# seed-workspace.sh [<title> <branch files> <open|none> [<main files>...]]
#
# Seed the run's empty working directory with the repository acme/orders:
# main holds the tree under workspace/ and the files of each <main files>
# directory, and the state of the OpenTofu root infra/staging, in
# .git/forge/cloud, is applied from main. The files under <branch files>, or
# under branch/, are the one commit of feat/debug-staging-logs, titled
# <title>, checked out and pushed. With open, the default, that branch is open
# as pull request 71; with none, it has no pull request.
#
# The forge is a stand-in for GitHub: the remote is a bare repository under
# .git/forge, and .git/forge/bin, which the case puts in front of the PATH,
# holds the stand-in gh, and the tofu and shfmt of the devkit's nixpkgs.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
evals=$(dirname "$here")
branch=feat/debug-staging-logs
title=${1:-"feat(infra): log at debug level in staging"}
branch_files=${2:-$here/branch}
pull_request=${3:-open}
main_files=("${@:4}")
if [[ $pull_request != open && $pull_request != none ]]; then
  echo "seed: the third argument is open or none, not $pull_request" >&2
  exit 1
fi
forge=.git/forge
devenv_lock=$(cd "$evals/../../.." && pwd)/devenv.lock
devenv_nixpkgs=$(nix eval --impure --raw --expr "with (builtins.fromJSON (builtins.readFile \"$devenv_lock\")).nodes.nixpkgs.locked; \"github:\" + owner + \"/\" + repo + \"/\" + rev")

export GIT_AUTHOR_NAME="Ada Lovelace" GIT_AUTHOR_EMAIL=ada@example.com GIT_AUTHOR_DATE=2026-11-10T09:00:00Z
export GIT_COMMITTER_NAME="Ada Lovelace" GIT_COMMITTER_EMAIL=ada@example.com GIT_COMMITTER_DATE=2026-11-10T09:00:00Z
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0

cp -R "$here/workspace/." .
for files in "${main_files[@]}"; do
  cp -R "$files/." .
done
git init -q -b main
git config user.name "Ada Lovelace"
git config user.email ada@example.com
git add -A
git commit -q -m "feat(infra): describe the staging resources of the orders service"

mkdir -p "$forge/bin" "$forge/cloud"
cp "$evals/pull-request-says-it-met-nothing/forge/gh" "$forge/bin/gh"
chmod +x "$forge/bin/gh"
echo acme/orders >"$forge/repository"
ln -s "$(nix build --no-link --print-out-paths "$devenv_nixpkgs#opentofu")/bin/tofu" "$forge/bin/tofu"
ln -s "$(nix build --no-link --print-out-paths "$devenv_nixpkgs#shfmt")/bin/shfmt" "$forge/bin/shfmt"
"$forge/bin/tofu" -chdir=infra/staging init -input=false >/dev/null
"$forge/bin/tofu" -chdir=infra/staging apply -input=false -auto-approve >/dev/null
git init -q --bare -b main "$forge/origin.git"
git remote add origin "$PWD/$forge/origin.git"
git push -q origin main
git remote set-head origin main

git switch -q -c "$branch"
cp -R "$branch_files/." .
git add -A
git commit -q -m "$title"
git push -q -u origin "$branch"
if [[ $pull_request == open ]]; then
  "$forge/bin/gh" pr create --title "$title" --body "Changes infra/ only. Live state follows when the change is applied." >/dev/null
fi
