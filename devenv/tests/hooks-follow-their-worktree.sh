#!/usr/bin/env bash
# Check that a commit runs the git hooks of the checkout it is made in. A
# throwaway repository imports the baseline and has two worktrees whose hook
# configurations differ. devenv is entered in one and then in the other, and a
# commit in each must run its own hooks whichever entered last. A third
# worktree never enters devenv, and a commit there must fail. A shim that an
# older baseline left for a hook type the configuration has dropped must be
# gone once devenv is entered, and a hook written by hand must stay. Run
# through `devenv test`.
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

# hook_configuration <tree> [message]: the tree's devenv.nix. Its own hook
# writes the name of the tree into the file hooks-ran of the tree a commit is
# made in. With `message` the tree also has a hook on the commit message,
# which writes the name into message-hooks-ran.
hook_configuration() {
  local tree=$1 message_hook=""
  if [[ ${2:-} == message ]]; then
    message_hook="
  git-hooks.hooks.which-message-hooks = {
    enable = true;
    name = \"which message hooks\";
    entry = \"\${pkgs.writeShellScript \"which-message-hooks\" \"echo $tree >message-hooks-ran\"}\";
    stages = [ \"commit-msg\" ];
    always_run = true;
  };"
  fi
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
$message_hook
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
# of the commit, `ran` to the tree whose hooks it ran and `message_ran` to the
# tree whose hook on the message it ran, each empty for none.
commit_in() {
  local tree=$1
  rm -f "$tmp/$tree/hooks-ran" "$tmp/$tree/message-hooks-ran"
  echo "a change" >>"$tmp/$tree/notes.txt"
  git -C "$tmp/$tree" add notes.txt
  status=0
  output=$(git -C "$tmp/$tree" commit -q -m "test: a change" 2>&1) || status=$?
  ran=$(cat "$tmp/$tree/hooks-ran" 2>/dev/null || true)
  message_ran=$(cat "$tmp/$tree/message-hooks-ran" 2>/dev/null || true)
}

# plant_legacy_shim: a commit-msg shim in the hooks directory that the
# worktrees share, as a baseline wrote it before the path from the root, for a
# hook the configuration has since dropped. It names its configuration by an
# absolute path, and the checkout that held the configuration is gone.
plant_legacy_shim() {
  local output
  mkdir "$tmp/gone"
  cp "$tmp/main/.pre-commit-config.yaml" "$tmp/gone/.pre-commit-config.yaml"
  if ! output=$(cd "$tmp/main" && "$devenv" shell -- prek install -c "$tmp/gone/.pre-commit-config.yaml" -t commit-msg 2>&1); then
    echo "FAIL: prek install of a commit-msg shim:" && echo "  ${output//$'\n'/$'\n'  }"
    exit 1
  fi
  rm -r "$tmp/gone"
}

# hand_written_hook: a prepare-commit-msg hook that no tool generated. It
# leaves the file by-hand-ran behind when a commit runs it.
hand_written_hook() {
  printf '%s\n' '#!/bin/sh' "echo ran >'$tmp/by-hand-ran'" >"$tmp/main/.git/hooks/prepare-commit-msg"
  chmod +x "$tmp/main/.git/hooks/prepare-commit-msg"
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

# expect_message_hook <label> <tree>: a commit there passes and runs the
# tree's hook on the message.
expect_message_hook() {
  local label=$1 tree=$2
  commit_in "$tree"
  if ((status == 0)) && [[ "$message_ran" == "$tree" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected the hook on the message of '$tree', got that of '${message_ran:-no tree}' and exit $status:"
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
printf '%s\n' '.devenv*' .pre-commit-config.yaml .mcp.json hooks-ran message-hooks-ran >"$tmp/main/.gitignore"
hook_configuration main
git -C "$tmp/main" add --all
git -C "$tmp/main" commit -q -m "chore: set up"

# Only the linked worktree has a hook on the commit message, so the main
# checkout's configuration uses no commit-msg shim.
for tree in linked unentered; do
  git -C "$tmp/main" worktree add -q -b "$tree" "$tmp/$tree"
done
hook_configuration linked message
hook_configuration unentered
for tree in linked unentered; do
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
expect_message_hook "main checkout entered last: the hook on the message that only the linked worktree has" linked

expect_refused "commit in a worktree that never entered devenv" unentered

plant_legacy_shim
hand_written_hook
enter main
expect_own_hooks "a shim that names a checkout that is gone: commit in the main checkout" main
expect_message_hook "a shim that names a checkout that is gone: the hook on the message of the linked worktree" linked
if [[ -f "$tmp/by-hand-ran" ]]; then
  echo "ok: a hook written by hand still runs"
else
  echo "FAIL: a hook written by hand still runs: no commit ran it"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "test-hooks-follow-their-worktree: $failures failure(s)" >&2
  exit 1
fi
echo "test-hooks-follow-their-worktree: ok"
