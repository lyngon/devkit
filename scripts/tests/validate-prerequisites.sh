#!/usr/bin/env bash
# Exercise validate-prerequisites.py against throwaway marketplaces: one case
# per rule in docs/conventions/prerequisites.md, plus clean plugins. Run
# through `devenv test`.
set -euo pipefail

validator=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/validate-prerequisites.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
failures=0

# --- Fixture helpers ---------------------------------------------------------

new_repo() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q
  mkdir -p "$repo/.claude-plugin" "$repo/plugins" "$repo/shared"
  echo "$repo"
}

# Rewrite marketplace.json from the plugin directories present.
manifest() {
  local repo=$1 entries="" dir name
  for dir in "$repo"/plugins/*/; do
    name=$(basename "$dir")
    entries+="{\"name\": \"$name\", \"source\": \"./plugins/$name\"},"
  done
  printf '{"name": "test", "owner": {"name": "t"}, "plugins": [%s]}\n' "${entries%,}" >"$repo/.claude-plugin/marketplace.json"
}

# plugin <repo> <name> <prerequisites line>: a plugin with one empty skill.
plugin() {
  local repo=$1 name=$2 line=$3 dir="$1/plugins/$2"
  mkdir -p "$dir/.claude-plugin" "$dir/skills/main"
  printf '{"name": "%s", "version": "0.1.0"}\n' "$name" >"$dir/.claude-plugin/plugin.json"
  printf '# %s\n\nPrerequisites: %s\n' "$name" "$line" >"$dir/README.md"
  printf -- '---\nname: main\ndescription: Test skill.\n---\n\n# Main\n' >"$dir/skills/main/SKILL.md"
  manifest "$repo"
}

# bundle <repo> <name> <prerequisites line> <dependency>...: no components.
bundle() {
  local repo=$1 name=$2 line=$3 dir="$1/plugins/$2" deps
  shift 3
  deps=$(printf '"%s",' "$@")
  mkdir -p "$dir/.claude-plugin"
  printf '{"name": "%s", "version": "0.1.0", "dependencies": [%s]}\n' "$name" "${deps%,}" >"$dir/.claude-plugin/plugin.json"
  printf '# %s\n\nPrerequisites: %s\n' "$name" "$line" >"$dir/README.md"
  manifest "$repo"
}

skill() {
  echo "$1/plugins/$2/skills/main/SKILL.md"
}

# --- Assertions --------------------------------------------------------------

run_validator() {
  (cd "$1" && python3 "$validator" 2>&1) || true
}

expect_ok() {
  local label=$1 repo=$2 output
  output=$(run_validator "$repo")
  if [[ "$output" == "validate-prerequisites: ok" ]]; then
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
  if grep -qF -- "$fragment" <<<"$output" && grep -qE 'validate-prerequisites: [0-9]+ error' <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

repo=$(new_repo)
plugin "$repo" plain git
echo "Nothing to see here." >>"$(skill "$repo" plain)"
expect_ok "plugin declaring git with no terms" "$repo"

repo=$(new_repo)
plugin "$repo" docs documents
echo "Terms are in CONCEPTS.md." >>"$(skill "$repo" docs)"
expect_ok "declared documents term" "$repo"

repo=$(new_repo)
plugin "$repo" plain git
echo "Put it under apps/." >>"$(skill "$repo" plain)"
expect_error "undeclared structure term" "$repo" "plugins/plain/skills/main/SKILL.md:7: names 'apps/' but the plugin declares prerequisites: none"

repo=$(new_repo)
plugin "$repo" plain git
printf '\n## With the Lyngon structure\n\nPut it under apps/.\n' >>"$(skill "$repo" plain)"
expect_ok "term inside a conditional section" "$repo"

repo=$(new_repo)
plugin "$repo" plain git
printf '\n## With the Lyngon structure\n\nFine here.\n\n## Elsewhere\n\nPut it under apps/.\n' >>"$(skill "$repo" plain)"
expect_error "term after the section ends" "$repo" "SKILL.md:14: names 'apps/'"

repo=$(new_repo)
plugin "$repo" docs documents
printf '\n### With devenv\n\nRun devenv test.\n\n## Next\n\nAlso devenv.\n' >>"$(skill "$repo" docs)"
expect_error "higher-level heading closes the section" "$repo" "SKILL.md:14: names 'devenv' but the plugin declares prerequisites: documents"

repo=$(new_repo)
plugin "$repo" plain git
printf -- '\n## With devenv\n\nTools come from devenv.nix.\n' >>"$(skill "$repo" plain)"
expect_ok "devenv term under a With devenv heading" "$repo"

repo=$(new_repo)
plugin "$repo" plain git
printf -- '\n## With devenv\n\nSet lyngon.enable in devenv.nix.\n' >>"$(skill "$repo" plain)"
expect_error "baseline term under a With devenv heading" "$repo" "SKILL.md:10: names 'lyngon.enable'"

repo=$(new_repo)
plugin "$repo" plain git
printf -- '\n## With the Lyngon baseline\n\nSet lyngon.enable in devenv.nix; the ruff hook runs.\n' >>"$(skill "$repo" plain)"
expect_ok "baseline and devenv terms under a baseline heading" "$repo"

repo=$(new_repo)
plugin "$repo" base baseline
printf -- '\nTools come from devenv.nix and the ruff hook runs.\n' >>"$(skill "$repo" base)"
expect_ok "devenv term with baseline declared" "$repo"

repo=$(new_repo)
plugin "$repo" conv git
printf -- '---\nname: main\ndescription: Nix.\npaths:\n  - "**/*.nix"\n  - devenv.yaml\n---\n\nSet lyngon.enable in devenv.nix.\n' >"$(skill "$repo" conv)"
expect_error "paths never make a skill conditional" "$repo" "SKILL.md:9: names 'devenv'"

repo=$(new_repo)
plugin "$repo" plain git
printf -- '---\nname: main\ndescription: Nix and devenv conventions.\npaths:\n  - devenv.yaml\n---\n\nNothing here.\n' >"$(skill "$repo" plain)"
expect_ok "frontmatter is not scanned" "$repo"

repo=$(new_repo)
plugin "$repo" plain git
printf -- '\n## With the Lyngon structure\n\nSet lyngon.structure.enable in devenv.nix.\n' >>"$(skill "$repo" plain)"
expect_ok "structure section allows baseline and devenv terms" "$repo"

repo=$(new_repo)
plugin "$repo" plain git
echo "The layout is in STRUCTURE.md." >"$repo/shared/STRUCTURE.md"
ln -s ../../../../shared/STRUCTURE.md "$repo/plugins/plain/skills/main/STRUCTURE.md"
expect_error "symlinked shared document" "$repo" "plugins/plain/skills/main/STRUCTURE.md:1: names 'STRUCTURE.md'"

repo=$(new_repo)
plugin "$repo" docs documents
plugin "$repo" env baseline
bundle "$repo" all "documents, baseline" docs env
expect_ok "bundle declaring the union" "$repo"

repo=$(new_repo)
plugin "$repo" docs documents
plugin "$repo" env baseline
bundle "$repo" all documents docs env
expect_error "bundle not declaring the union" "$repo" "plugins/all/README.md: bundle must declare the union of its dependencies: Prerequisites: documents, baseline"

repo=$(new_repo)
plugin "$repo" plain git
sed -i '/^Prerequisites:/d' "$repo/plugins/plain/README.md"
expect_error "missing Prerequisites line" "$repo" "plugins/plain/README.md: needs exactly one 'Prerequisites:' line, found 0"

repo=$(new_repo)
plugin "$repo" plain "baseline, documents"
expect_error "prerequisites out of order" "$repo" "plugins/plain/README.md: prerequisites must be listed once each in the order"

repo=$(new_repo)
plugin "$repo" docs documents
plugin "$repo" env baseline
bundle "$repo" core documents docs
expect_ok "core listing exactly the documents-only plugins" "$repo"

repo=$(new_repo)
plugin "$repo" docs documents
plugin "$repo" plain git
bundle "$repo" core documents docs
expect_error "core missing a documents-only plugin" "$repo" "plugins/core/.claude-plugin/plugin.json: core must list exactly the plugins declaring at most documents: docs, plain"

repo=$(new_repo)
plugin "$repo" docs documents
plugin "$repo" env baseline
bundle "$repo" core "documents, baseline" docs env
expect_error "core holding a devenv plugin" "$repo" "core must list exactly the plugins declaring at most documents: docs"

if ((failures > 0)); then
  echo "test-validate-prerequisites: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-prerequisites: ok"
