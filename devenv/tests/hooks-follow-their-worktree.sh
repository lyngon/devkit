#!/usr/bin/env bash
# Check that a commit runs the git hooks of the checkout it is made in. A
# throwaway repository imports the baseline and has two worktrees whose hook
# configurations differ. devenv is entered in one and then in the other, and a
# commit in each must run its own hooks whichever entered last. A third
# worktree never enters devenv, and a commit there must fail. Run through
# `devenv test`.
#
# Usage: hooks-follow-their-worktree.sh <devenv> <devenv.lock>
#
# The lock file pins the nixpkgs and git-hooks inputs of the throwaway
# repository. With pins that are already in the Nix store nothing is fetched.
set -euo pipefail

usage="usage: hooks-follow-their-worktree.sh <devenv> <devenv.lock>"
devenv=${1:?$usage}
lock=${2:?$usage}
baseline=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# Neither the git configuration nor the hook cache of whoever runs the test.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PREK_HOME="$tmp/prek"
failures=0

# --- Fixture helpers ---------------------------------------------------------

# hook_configuration <tree>: the tree's devenv.nix. Its own hook writes the
# name of the tree into the file hooks-ran of the tree a commit is made in.
hook_configuration() {
  local tree=$1
  cat >"$tmp/$tree/devenv.nix" <<EOF
{ pkgs, ... }:
{
  lyngon.enable = true;

  # The fixture has none of the standard documents.
  git-hooks.hooks.validate-documents.enable = false;

  git-hooks.hooks.which-hooks = {
    enable = true;
    name = "which hooks";
    entry = "\${pkgs.writeShellScript "which-hooks" "echo $tree >hooks-ran"}";
    always_run = true;
    pass_filenames = false;
  };
}
EOF
}

# enter <tree>: enter devenv there, which installs the git hooks.
enter() {
  local tree=$1 output
  if ! output=$(cd "$tmp/$tree" && "$devenv" shell -- true 2>&1); then
    echo "FAIL: devenv shell in the tree '$tree':" && echo "  ${output//$'\n'/$'\n'  }"
    exit 1
  fi
}

# commit_in <tree>: commit a change there. Sets `status` and `output` to those
# of the commit, and `ran` to the tree whose hooks it ran, empty for none.
commit_in() {
  local tree=$1
  rm -f "$tmp/$tree/hooks-ran"
  echo "a change" >>"$tmp/$tree/notes.txt"
  git -C "$tmp/$tree" add notes.txt
  status=0
  output=$(git -C "$tmp/$tree" commit -q -m "test: a change" 2>&1) || status=$?
  ran=$(cat "$tmp/$tree/hooks-ran" 2>/dev/null || true)
}

# --- Assertions --------------------------------------------------------------

# expect_own_hooks <label> <tree>: a commit there passes on the tree's hooks.
expect_own_hooks() {
  local label=$1 tree=$2
  commit_in "$tree"
  if ((status == 0)) && [[ "$ran" == "$tree" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected the hooks of '$tree', got those of '${ran:-no tree}' and exit $status:"
    echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_refused <label> <tree>: a commit there fails, says why and runs no hook.
expect_refused() {
  local label=$1 tree=$2
  commit_in "$tree"
  if ((status != 0)) && [[ -n "$output" && -z "$ran" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected a refusal, got the hooks of '${ran:-no tree}' and exit $status:"
    echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Fixture -----------------------------------------------------------------

# The baseline as a repository receives it: an input that holds devenv/.
mkdir "$tmp/lyngon"
cp -R "$baseline" "$tmp/lyngon/devenv"

git init -q -b main "$tmp/main"
git -C "$tmp/main" config user.name "Hooks test"
git -C "$tmp/main" config user.email hooks-test@example.invalid
cat >"$tmp/main/devenv.yaml" <<EOF
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
cp "$lock" "$tmp/main/devenv.lock"
printf '%s\n' '.devenv*' .pre-commit-config.yaml .mcp.json hooks-ran >"$tmp/main/.gitignore"
hook_configuration main
git -C "$tmp/main" add --all
git -C "$tmp/main" commit -q -m "chore: set up"

for tree in linked unentered; do
  git -C "$tmp/main" worktree add -q -b "$tree" "$tmp/$tree"
  hook_configuration "$tree"
  git -C "$tmp/$tree" commit -q --all -m "feat: the hooks of $tree"
done

# --- Cases -------------------------------------------------------------------

enter main
enter linked
expect_own_hooks "linked worktree entered last: commit in the main checkout" main
expect_own_hooks "linked worktree entered last: commit in the linked worktree" linked

enter main
expect_own_hooks "main checkout entered last: commit in the linked worktree" linked
expect_own_hooks "main checkout entered last: commit in the main checkout" main

expect_refused "commit in a worktree that never entered devenv" unentered

if ((failures > 0)); then
  echo "test-hooks-follow-their-worktree: $failures failure(s)" >&2
  exit 1
fi
echo "test-hooks-follow-their-worktree: ok"
