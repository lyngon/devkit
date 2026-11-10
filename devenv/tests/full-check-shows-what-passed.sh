#!/usr/bin/env bash
set -euo pipefail

usage="usage: full-check-shows-what-passed.sh <devenv> <devenv.lock>"
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

expect() {
  if grep -qE -- "$2" <<<"$output"; then
    echo "ok: $1"
  else
    echo "FAIL: $1: no line matches '$2'"
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
printf '%s\n' '.devenv*' .pre-commit-config.yaml .mcp.json hook-runs >"$repo/.gitignore"
cat >"$repo/devenv.nix" <<'EOF'
{ pkgs, ... }:
{
  lyngon.enable = true;

  git-hooks.hooks.validate-documents.enable = false;

  git-hooks.hooks.passing-hook = {
    enable = true;
    name = "passing hook";
    entry = "${pkgs.writeShellScript "passing-hook" "echo ran >>hook-runs"}";
    always_run = true;
    pass_filenames = false;
  };
  git-hooks.hooks.hook-without-files = {
    enable = true;
    name = "hook without files";
    entry = "${pkgs.coreutils}/bin/true";
    files = "^no-such-file$";
  };

  tasks."fixture:test" = {
    exec = "echo 'the test task of the fixture ran'";
    before = [ "devenv:enterTest" ];
  };

  enterTest = ''
    echo "enterTest of the fixture ran"
  '';
}
EOF
git -C "$repo" add --all

status=0
output=$(cd "$repo" && "$devenv" test 2>&1) || status=$?

if ((status == 0)); then
  echo "ok: the full check exits 0"
else
  echo "FAIL: the full check exits 0: it exited $status"
  failures=$((failures + 1))
fi
expect "the full check names the hook that passed as passed" '^ *passing hook\.+Passed$'
expect "the full check names the hook without files as skipped for want of files" '^ *hook without files\.+\(no files to check\)Skipped$'
expect "the full check shows the output of a task that runs before enterTest" '^ *the test task of the fixture ran$'
expect "the full check shows the output of enterTest" '^ *enterTest of the fixture ran$'
runs=$(cat "$repo/hook-runs" 2>/dev/null || true)
if [[ $runs == ran ]]; then
  echo "ok: the full check ran the passing hook once"
else
  echo "FAIL: the full check ran the passing hook once: its runs left '${runs//$'\n'/ }'"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "the output of the full check:" && echo "  ${output//$'\n'/$'\n'  }"
  echo "test-full-check-shows-what-passed: $failures failure(s)" >&2
  exit 1
fi
echo "test-full-check-shows-what-passed: ok"
