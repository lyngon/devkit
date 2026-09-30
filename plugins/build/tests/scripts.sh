#!/usr/bin/env bash
# Exercise the build plugin's scripts against throwaway git repositories and
# plans. The repository's full check runs this file.
set -euo pipefail

build=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
delegate=$build/skills/delegate/scripts
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

# --- Assertions --------------------------------------------------------------

check() {
  local label=$1
  shift
  if "$@"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

equals() {
  [[ "$1" == "$2" ]] || {
    echo "  expected: $2"
    echo "  actual:   $1"
    return 1
  }
}

contains() {
  grep -qF -- "$2" <<<"$1" || {
    echo "  missing: $2"
    return 1
  }
}

lacks() {
  ! grep -qF -- "$2" <<<"$1" || {
    echo "  unexpected: $2"
    return 1
  }
}

# run <command>...: run a command, capturing stdout, stderr and the exit code
# in out, err and code.
run() {
  code=0
  out=$("$@" 2>"$tmp/stderr" </dev/null) || code=$?
  err=$(<"$tmp/stderr")
}

# new_repo <name>: a git repository with one commit, printed as its path.
new_repo() {
  local repo=$tmp/$1
  mkdir -p "$repo/docs/plans"
  git -C "$repo" init -q -b main
  git -C "$repo" commit -q --allow-empty -m "chore: start"
  echo "$repo"
}

# --- pin ---------------------------------------------------------------------

repo=$(new_repo pin)
printf 'hello\n' >"$repo/artifact.txt"
hello=5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
run bash "$delegate/pin" "$repo/artifact.txt"
check "pin: prints sha256:<hex> and the file" \
  equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/artifact.txt"
check "pin --check: a matching pin exits 0 and prints nothing" \
  equals "$code|$out|$err" "0||"
printf 'hello!\n' >"$repo/edited.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/edited.txt"
check "pin --check: an edited file exits 1 and names both hashes" \
  equals "$code|$(grep -c "pinned sha256:$hello, found sha256:" <<<"$err")" "1|1"
run bash "$delegate/pin" --check "sha256:abc" "$repo/artifact.txt"
check "pin --check: a malformed pin is a usage error" \
  equals "$code" "2"
run bash "$delegate/pin" "$repo/missing.txt"
check "pin: a missing file is an error, with nothing printed" \
  equals "$code|$out" "2|"
for tool in sha256sum shasum; do
  only=$tmp/only-$tool
  mkdir -p "$only"
  ln -s "$(command -v bash)" "$only/bash"
  ln -s "$(command -v "$tool")" "$only/$tool"
  run env -i PATH="$only" "$only/bash" "$delegate/pin" "$repo/artifact.txt"
  check "pin: works with $tool alone" \
    equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
done
none=$tmp/no-hash-tool
mkdir -p "$none"
ln -s "$(command -v bash)" "$none/bash"
run env -i PATH="$none" "$none/bash" "$delegate/pin" "$repo/artifact.txt"
check "pin: without a hash tool, exits 2 and says so" \
  equals "$code|$err" "2|pin: neither sha256sum nor shasum is on PATH"

# --- review-package ----------------------------------------------------------

repo=$(new_repo review-package)
printf '# Plan\n' >"$repo/docs/plans/2026-01-01-demo.md"
git -C "$repo" add docs/plans/2026-01-01-demo.md
git -C "$repo" commit -q -m "docs: add the plan"
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" commit -q --allow-empty -m "chore: record the apply of demo.tfplan" \
  -m "Gate apply-demo: owner 2026-01-01T10:00:00+0000: \"yes\""
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md "$3" HEAD' _ "$repo" "$delegate" "$base"
package=$(cat "$out" 2>/dev/null || true)
check "review-package: a range holding only an empty record commit makes a package" \
  equals "$code" "0"
check "review-package: the package shows the record commit's evidence" \
  contains "$package" 'Gate apply-demo: owner 2026-01-01T10:00:00+0000: "yes"'
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md HEAD HEAD' _ "$repo" "$delegate"
check "review-package: an empty range is still refused" \
  equals "$code" "3"

# --- Summary -----------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
  echo "build scripts: $failures failure(s)"
  exit 1
fi
echo "build scripts: all passed"
