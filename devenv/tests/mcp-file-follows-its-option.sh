#!/usr/bin/env bash
# Check that lyngon.mcp.enable decides whether entering devenv writes .mcp.json.
# A throwaway repository imports the baseline and enters devenv with the
# option on, which must write the file with the devenv server, and then without
# setting it, which must remove the file it wrote before: the server is off
# unless a repository turns it on. Run through `devenv test`.
#
# Usage: mcp-file-follows-its-option.sh <devenv> <devenv.lock>
#
# The lock file pins the nixpkgs and git-hooks inputs of the throwaway
# repository. With pins that are already in the Nix store nothing is fetched.
set -euo pipefail

usage="usage: mcp-file-follows-its-option.sh <devenv> <devenv.lock>"
devenv=${1:?$usage}
lock=${2:?$usage}
baseline=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# Neither the git configuration nor the hook cache of whoever runs the test.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PREK_HOME="$tmp/prek"
repo=$tmp/repo
failures=0

# configure <extra line>: the repository's devenv.nix, with the line added.
configure() {
  cat >"$repo/devenv.nix" <<EOF
{
  lyngon.enable = true;

  # The fixture has none of the standard documents.
  git-hooks.hooks.validate-documents.enable = false;
  $1
}
EOF
}

# enter: enter devenv in the repository. Sets `status`, and `output` to the
# lines of devenv's errors, since it traces every file it evaluates.
enter() {
  local log
  status=0
  log=$(cd "$repo" && "$devenv" shell -- true 2>&1) || status=$?
  output=$(grep 'error:' <<<"$log" | sed 's/\x1b\[[0-9;]*m//g' || true)
}

fail() {
  echo "FAIL: $1:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
}

# The baseline as a repository receives it: an input that holds devenv/.
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

label="with lyngon.mcp.enable = true, entering devenv writes .mcp.json with the devenv server"
configure "lyngon.mcp.enable = true;"
enter
if ((status != 0)); then
  fail "$label: devenv shell exited $status"
elif ! jq -e '.mcpServers.devenv | .command == "devenv" and .args == ["mcp"]' "$repo/.mcp.json" >/dev/null 2>&1; then
  output=$(cat "$repo/.mcp.json" 2>&1 || true)
  fail "$label: .mcp.json lacks the devenv server"
else
  echo "ok: $label"
fi

label="by default, entering devenv removes the .mcp.json it wrote before and writes none"
configure ""
enter
if ((status != 0)); then
  fail "$label: devenv shell exited $status"
elif [[ -e $repo/.mcp.json || -L $repo/.mcp.json ]]; then
  output=$(ls -l "$repo/.mcp.json")
  fail "$label: .mcp.json is still there"
else
  echo "ok: $label"
fi

if ((failures > 0)); then
  echo "test-mcp-file-follows-its-option: $failures failure(s)" >&2
  exit 1
fi
echo "test-mcp-file-follows-its-option: ok"
