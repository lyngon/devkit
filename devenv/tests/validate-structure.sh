#!/usr/bin/env bash
# Exercise validate-structure.py against throwaway fixture repositories: one
# per rule in shared/STRUCTURE.md section 4.4, plus a clean repository in
# every language and an empty one. Run through `devenv test`.
set -euo pipefail

validator=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/validate-structure.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
failures=0

# --- Fixture helpers ---------------------------------------------------------

new_repo() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q
  echo "$repo"
}

# The four documents every app and library carries.
package_docs() {
  local dir=$1
  touch "$dir/README.md" "$dir/INTENT.md" "$dir/CLAUDE.md"
  ln -sfn CLAUDE.md "$dir/AGENTS.md"
}

# py_pkg <repo> <path> <name> [dep...]
py_pkg() {
  local repo=$1 path=$2 name=$3
  shift 3
  mkdir -p "$repo/$path"
  package_docs "$repo/$path"
  {
    echo "[project]"
    echo "name = \"$name\""
    echo "version = \"0\""
    echo "dependencies = [$(printf '"%s", ' "$@")]"
  } >"$repo/$path/pyproject.toml"
}

# py_workspace <repo> [member...]
py_workspace() {
  local repo=$1
  shift
  printf '[tool.uv.workspace]\nmembers = [%s]\n' "$(printf '"%s", ' "$@")" >"$repo/pyproject.toml"
}

# A clean two-package Python repository: an app depending on a library.
clean_py_repo() {
  local repo
  repo=$(new_repo)
  py_pkg "$repo" libs/orders orders
  py_pkg "$repo" apps/orders-api orders-api orders
  py_workspace "$repo" libs/orders apps/orders-api
  echo "$repo"
}

# A clean repository with a TypeScript, a Rust and a Go workspace.
clean_polyglot_repo() {
  local repo
  repo=$(new_repo)
  mkdir -p "$repo/libs/web" "$repo/apps/web-ui" "$repo/libs/core" "$repo/apps/core-cli" "$repo/libs/gate" "$repo/apps/gate-api"
  for dir in libs/web apps/web-ui libs/core apps/core-cli libs/gate apps/gate-api; do
    package_docs "$repo/$dir"
  done
  echo '{"name": "@acme/web"}' >"$repo/libs/web/package.json"
  echo '{"name": "@acme/web-ui", "dependencies": {"@acme/web": "workspace:*"}}' >"$repo/apps/web-ui/package.json"
  printf 'packages:\n  - "libs/web"\n  - apps/web-ui\n' >"$repo/pnpm-workspace.yaml"
  printf '[package]\nname = "core"\n' >"$repo/libs/core/Cargo.toml"
  printf '[package]\nname = "core-cli"\n[dependencies]\ncore = { workspace = true }\n' >"$repo/apps/core-cli/Cargo.toml"
  printf '[workspace]\nmembers = ["libs/core", "apps/core-cli"]\n[workspace.dependencies]\ncore = { path = "libs/core" }\n' >"$repo/Cargo.toml"
  printf 'module example.com/gate\n' >"$repo/libs/gate/go.mod"
  printf 'module example.com/gate-api\nrequire example.com/gate v0.0.0\nreplace example.com/gate => ../../libs/gate\n' >"$repo/apps/gate-api/go.mod"
  printf 'use (\n\t./libs/gate\n\t./apps/gate-api\n)\n' >"$repo/go.work"
  echo "$repo"
}

# --- Assertions --------------------------------------------------------------

run_validator() {
  (cd "$1" && python3 "$validator" 2>&1) || true
}

expect_ok() {
  local label=$1 repo=$2 output
  output=$(run_validator "$repo")
  if [[ "$output" == "validate-structure: ok" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_error <label> <repo> <fragment>: the run fails and mentions the fragment.
expect_error() {
  local label=$1 repo=$2 fragment=$3 output
  output=$(run_validator "$repo")
  if grep -qF -- "$fragment" <<<"$output" && grep -qE 'validate-structure: [0-9]+ error' <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

expect_ok "empty repository" "$(new_repo)"
expect_ok "clean Python repository" "$(clean_py_repo)"
expect_ok "clean TypeScript, Rust and Go repository" "$(clean_polyglot_repo)"

repo=$(clean_py_repo)
py_pkg "$repo" libs/orders orders orders-api
expect_error "rule 1: library depends on app" "$repo" "libs/orders: depends on app apps/orders-api"

repo=$(clean_py_repo)
py_pkg "$repo" tools/orders-gen orders-gen
py_pkg "$repo" libs/orders orders orders-gen
py_workspace "$repo" libs/orders apps/orders-api tools/orders-gen
expect_error "rule 2: library depends on tool" "$repo" "libs/orders: depends on tools/orders-gen"

repo=$(clean_py_repo)
py_workspace "$repo" libs/orders
expect_error "rule 3: package missing from members" "$repo" "apps/orders-api: not listed in pyproject.toml"

repo=$(clean_py_repo)
py_workspace "$repo" libs/orders apps/orders-api libs/gone
expect_error "rule 3: member does not exist" "$repo" "entry 'libs/gone' does not exist"

repo=$(clean_py_repo)
py_workspace "$repo" "libs/*" "apps/*"
expect_error "rule 3: glob member" "$repo" "entry 'libs/*' is a glob"

repo=$(clean_py_repo)
rm "$repo/pyproject.toml"
expect_error "rule 3: no workspace file" "$repo" "pyproject.toml: [tool.uv.workspace] members is missing"

repo=$(clean_py_repo)
rm "$repo/libs/orders/INTENT.md"
expect_error "rule 4: missing INTENT.md" "$repo" "libs/orders: missing INTENT.md"

repo=$(clean_py_repo)
rm "$repo/apps/orders-api/AGENTS.md"
cp "$repo/apps/orders-api/CLAUDE.md" "$repo/apps/orders-api/AGENTS.md"
expect_error "rule 4: AGENTS.md is a copy" "$repo" "apps/orders-api: AGENTS.md must be a symlink to CLAUDE.md"

repo=$(clean_py_repo)
mkdir "$repo/libs/python"
expect_error "rule 5: language name as path segment" "$repo" "libs/python: named after a language"

if ((failures > 0)); then
  echo "test-validate-structure: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-structure: ok"
