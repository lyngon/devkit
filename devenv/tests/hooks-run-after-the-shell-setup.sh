#!/usr/bin/env bash
set -euo pipefail

usage="usage: hooks-run-after-the-shell-setup.sh <devenv> <devenv.lock>"
devenv=${1:?$usage}
lock=${2:?$usage}
baseline=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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

mkdir "$tmp/lyngon"
cp -R "$baseline" "$tmp/lyngon/devenv"

git init -q -b main "$repo"
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
printf '%s\n' '.devenv*' .pre-commit-config.yaml .mcp.json set-up >"$repo/.gitignore"
# The setup task takes longer than the hook install, as a uv sync that
# downloads does.
cat >"$repo/devenv.nix" <<'EOF'
{ pkgs, ... }:
{
  lyngon.enable = true;

  git-hooks.hooks.validate-documents.enable = false;

  tasks."fixture:setup" = {
    exec = "${pkgs.coreutils}/bin/sleep 2 && ${pkgs.coreutils}/bin/touch set-up";
    before = [ "devenv:enterShell" ];
  };
  git-hooks.hooks.needs-the-setup = {
    enable = true;
    name = "needs the setup";
    entry = "${pkgs.coreutils}/bin/test -e set-up";
    always_run = true;
    pass_filenames = false;
  };
}
EOF
git -C "$repo" add --all

status=0
output=$(cd "$repo" && "$devenv" test 2>&1) || status=$?
if ((status == 0)) && grep -qE '^ *needs the setup\.+Passed$' <<<"$output"; then
  check "the hooks of the full check run once the shell is set up" ok "$output"
else
  check "the hooks of the full check run once the shell is set up: it exited $status" fail "$output"
fi
if grep -q 'Running devenv:git-hooks:run' <<<"$output"; then
  check "the full check runs the hooks" ok "$output"
else
  check "the full check runs the hooks" fail "$output"
fi

status=0
output=$(cd "$repo" && "$devenv" shell -- true 2>&1) || status=$?
if ((status == 0)) && ! grep -q 'Running devenv:git-hooks:run' <<<"$output"; then
  check "entering the shell runs no hook" ok "$output"
else
  check "entering the shell runs no hook: it exited $status" fail "$output"
fi

if ((failures > 0)); then
  echo "test-hooks-run-after-the-shell-setup: $failures failure(s)" >&2
  exit 1
fi
echo "test-hooks-run-after-the-shell-setup: ok"
