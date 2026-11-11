#!/usr/bin/env bash
set -euo pipefail

usage="usage: package-test-runs-in-the-full-check-only.sh <devenv> <devenv.lock>"
devenv=${1:?$usage}
lock=${2:?$usage}
template=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/add-package/references/package-files.md
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE DEVENV_NO_AI_AGENT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PREK_HOME="$tmp/prek"
export CLAUDECODE=1
repo=$tmp/repo
failures=0

check() {
  local label=$1 verdict=$2 output=$3
  if [[ $verdict == ok ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    echo "  the output:" && echo "    ${output//$'\n'/$'\n'    }"
    failures=$((failures + 1))
  fi
}

git init -q -b main "$repo"
cat >"$repo/devenv.yaml" <<'EOF'
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
imports:
  - ./libs/fixture
EOF
cp "$lock" "$repo/devenv.lock"
printf '%s\n' '.devenv*' .pre-commit-config.yaml >"$repo/.gitignore"
# The package's tests fail, so that a run of them shows in the exit status.
cat >"$repo/devenv.nix" <<'EOF'
{ pkgs, ... }:
{
  packages = [
    (pkgs.writeShellScriptBin "uv" ''
      echo "the tests of the fixture ran and failed"
      exit 1
    '')
  ];
}
EOF
mkdir -p "$repo/libs/fixture"
awk '/^A Python library:$/ { found = 1; next }
  found && /^```nix$/ { inside = 1; next }
  inside && /^```$/ { exit }
  inside { print }' "$template" | sed 's/{name}/fixture/g' >"$repo/libs/fixture/devenv.nix"
if ! grep -q '"fixture:test"' "$repo/libs/fixture/devenv.nix"; then
  echo "FAIL: the Python library block of $template holds no task fixture:test"
  exit 1
fi
git -C "$repo" add --all

status=0
output=$(cd "$repo" && "$devenv" shell -- true 2>&1) || status=$?
if ((status == 0)) && ! grep -q 'Running fixture:test' <<<"$output"; then
  check "entering the shell runs no package test" ok "$output"
else
  check "entering the shell runs no package test: it exited $status" fail "$output"
fi

status=0
output=$(cd "$repo" && "$devenv" test 2>&1) || status=$?
if ((status != 0)) && grep -q '✖ Running fixture:test' <<<"$output"; then
  check "a failing package test fails the full check" ok "$output"
else
  check "a failing package test fails the full check: it exited $status" fail "$output"
fi

if ((failures > 0)); then
  echo "test-package-test-runs-in-the-full-check-only: $failures failure(s)" >&2
  exit 1
fi
echo "test-package-test-runs-in-the-full-check-only: ok"
