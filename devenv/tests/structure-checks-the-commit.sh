#!/usr/bin/env bash
set -euo pipefail

usage="usage: structure-checks-the-commit.sh <devenv> <devenv.lock>"
devenv=${1:?$usage}
lock=${2:?$usage}
baseline=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PREK_HOME="$tmp/prek"
repo=$tmp/repo
failures=0

py_pkg() {
  mkdir -p "$repo/$1"
  touch "$repo/$1/README.md"
  printf '[project]\nname = "%s"\nversion = "0"\ndependencies = []\n' "$2" >"$repo/$1/pyproject.toml"
}

py_workspace() {
  printf '[tool.uv.workspace]\nmembers = [%s]\n' "$(printf '"%s", ' "$@")" >"$repo/pyproject.toml"
}

mkdir "$tmp/lyngon"
cp -R "$baseline" "$tmp/lyngon/devenv"

git init -q -b main "$repo"
git -C "$repo" config user.name "Structure test"
git -C "$repo" config user.email structure-test@example.invalid
cat >"$repo/devenv.yaml" <<EOF
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  lyngon:
    url: path:$tmp/lyngon
    flake: false
imports:
  - lyngon/devenv
EOF
cp "$lock" "$repo/devenv.lock"
cat >"$repo/devenv.nix" <<'EOF'
{
  lyngon.enable = true;
  lyngon.structure.enable = true;

  git-hooks.hooks.validate-documents.enable = false;
}
EOF
printf '%s\n' '.devenv*' .pre-commit-config.yaml .mcp.json >"$repo/.gitignore"
py_pkg libs/orders orders
py_workspace libs/orders
git -C "$repo" add --all
git -C "$repo" commit -q -m "chore: set up"
base=$(git -C "$repo" rev-parse HEAD)

if ! output=$(cd "$repo" && "$devenv" shell -- true 2>&1); then
  echo "FAIL: devenv shell in the fixture:" && echo "  ${output//$'\n'/$'\n'  }"
  exit 1
fi

start_case() {
  git -C "$repo" reset -q --hard "$base"
  git -C "$repo" clean -q -f -d
}

expect_commit() {
  local label=$1 output
  if output=$(git -C "$repo" commit -q -m "test: a change" 2>&1); then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected the hooks to pass the commit, got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

expect_refused() {
  local label=$1 fragment=$2 output
  if output=$(git -C "$repo" commit -q -m "test: a change" 2>&1); then
    echo "FAIL: $label: expected the hooks to refuse the commit, it passed:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  elif grep -qF -- "$fragment" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

start_case
mkdir -p "$repo/apps/draft"
printf '[project]\nname = "draft"\nversion = "0"\n' >"$repo/apps/draft/pyproject.toml"
echo 'description = "Orders."' >>"$repo/libs/orders/pyproject.toml"
git -C "$repo" add libs/orders/pyproject.toml
expect_commit "untracked package that no workspace lists and that lacks README.md"

start_case
py_pkg libs/billing billing
py_workspace libs/orders libs/billing
git -C "$repo" add pyproject.toml
expect_refused "staged workspace that lists a package that is untracked" \
  "pyproject.toml: [tool.uv.workspace] members entry 'libs/billing' does not exist or has no pyproject.toml"

start_case
git -C "$repo" rm -q libs/orders/README.md
expect_refused "commit that only deletes a package's README.md" "libs/orders: missing README.md"

if ((failures > 0)); then
  echo "test-structure-checks-the-commit: $failures failure(s)" >&2
  exit 1
fi
echo "test-structure-checks-the-commit: ok"
