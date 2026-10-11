#!/usr/bin/env bash
# Exercise validate-marketplace.sh against throwaway marketplaces: a clean
# one, one without the `all` bundle, and skills whose frontmatter breaks a
# rule. Run through `devenv test`.
set -euo pipefail

validator=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/validate-marketplace.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
failures=0

# --- Fixture helpers ---------------------------------------------------------

# Rewrite marketplace.json from the plugin directories present; a plugin
# without skills is listed in category bundle.
manifest() {
  local repo=$1 entries="" dir name category
  for dir in "$repo"/plugins/*/; do
    name=$(basename "$dir")
    category=""
    [[ -d "$dir/skills" ]] || category=', "category": "bundle"'
    entries+="{\"name\": \"$name\", \"source\": \"./plugins/$name\", \"description\": \"Test plugin.\"$category},"
  done
  printf '{"name": "test", "owner": {"name": "t"}, "plugins": [%s]}\n' "${entries%,}" >"$repo/.claude-plugin/marketplace.json"
}

# plugin <repo> <name> [dependency...]: a plugin with one skill that links the
# shared document, or a bundle when dependencies are given.
plugin() {
  local repo=$1 name=$2 dir="$1/plugins/$2" deps=""
  shift 2
  mkdir -p "$dir/.claude-plugin"
  if (($# > 0)); then
    deps=$(printf '"%s",' "$@")
  else
    mkdir -p "$dir/skills/main"
    printf -- '---\nname: main\ndescription: Test skill.\n---\n\n# Main\n' >"$dir/skills/main/SKILL.md"
    ln -s ../../../../shared/SHARED.md "$dir/skills/main/SHARED.md"
  fi
  printf '{"name": "%s", "version": "0.1.0", "description": "Test plugin.", "license": "Apache-2.0", "dependencies": [%s]}\n' \
    "$name" "${deps%,}" >"$dir/.claude-plugin/plugin.json"
  echo "# Changelog" >"$dir/CHANGELOG.md"
  manifest "$repo"
}

# A clean marketplace: one plugin with a skill, and the `all` bundle over it.
clean_marketplace() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q
  mkdir -p "$repo/.claude-plugin" "$repo/plugins" "$repo/shared" "$repo/catalog"
  echo "# Shared" >"$repo/shared/SHARED.md"
  echo "# Catalog" >"$repo/catalog/README.md"
  plugin "$repo" one
  plugin "$repo" all one
  echo "$repo"
}

skill() {
  echo "$1/plugins/one/skills/main/SKILL.md"
}

# --- Assertions --------------------------------------------------------------

run_validator() {
  (cd "$1" && "$validator" 2>&1) || true
}

expect_ok() {
  local label=$1 repo=$2 output
  output=$(run_validator "$repo")
  if [[ "$output" == "validate-marketplace: ok" ]]; then
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
  if grep -qF -- "$fragment" <<<"$output" && grep -qE 'validate-marketplace: [0-9]+ error' <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

expect_ok "clean marketplace" "$(clean_marketplace)"

repo=$(clean_marketplace)
rm -r "$repo/plugins/all"
manifest "$repo"
expect_error "the all bundle is missing" "$repo" "plugins/all is missing: Claude Code installs one plugin per command, so a repository installs every plugin through this bundle"

repo=$(clean_marketplace)
plugin "$repo" two
expect_error "the all bundle misses a plugin" "$repo" "plugins/all: dependencies must be exactly: one two"

repo=$(clean_marketplace)
printf -- '---\ndescription: Test skill.\n---\n\n# Main\n' >"$(skill "$repo")"
expect_error "skill without a name" "$repo" "plugins/one/skills/main/SKILL.md: frontmatter needs a name equal to the directory name 'main'"

repo=$(clean_marketplace)
printf -- '---\nname: other\ndescription: Test skill.\n---\n\n# Main\n' >"$(skill "$repo")"
expect_error "skill named differently from its directory" "$repo" "plugins/one/skills/main/SKILL.md: frontmatter name 'other' differs from directory name 'main'"

repo=$(clean_marketplace)
printf -- '\n---\nname: main\ndescription: Test skill.\n---\n' >"$(skill "$repo")"
expect_error "frontmatter below line 1" "$repo" "plugins/one/skills/main/SKILL.md: frontmatter must start on line 1"

repo=$(clean_marketplace)
printf -- '---\nname: main\n---\n\n# Main\n' >"$(skill "$repo")"
expect_error "skill without a description" "$repo" "plugins/one/skills/main/SKILL.md: frontmatter needs a non-empty description"

if ((failures > 0)); then
  echo "test-validate-marketplace: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-marketplace: ok"
