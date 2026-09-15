#!/usr/bin/env bash
# Validate the marketplace manifest, every plugin directory, every SKILL.md
# and every catalog record. Encodes the rules from CLAUDE.md and ADR 0002.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

manifest=.claude-plugin/marketplace.json
errors=0

fail() {
  echo "error: $*" >&2
  errors=$((errors + 1))
}

kebab='^[a-z0-9]+(-[a-z0-9]+)*$'
semver='^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'
sha40='^[0-9a-f]{40}$'

[[ -f "$manifest" ]] || {
  fail "$manifest is missing"
  exit 1
}
jq -e . "$manifest" >/dev/null 2>&1 || {
  fail "$manifest is not valid JSON"
  exit 1
}

jq -e '.name and .owner.name and (.plugins | type == "array")' "$manifest" >/dev/null ||
  fail "$manifest needs name, owner.name and a plugins array"

check_skill() {
  local skill=$1
  local dir name
  dir=$(basename "$(dirname "$skill")")
  [[ "$dir" =~ $kebab && ${#dir} -le 64 ]] || fail "$skill: directory name '$dir' is not kebab-case or is longer than 64 characters"
  [[ "$(head -n 1 "$skill")" == "---" ]] || fail "$skill: frontmatter must start on line 1"
  grep -qE '^description:[[:space:]]*[^[:space:]]' "$skill" || fail "$skill: frontmatter needs a non-empty description"
  name=$(sed -n '2,/^---$/p' "$skill" | sed -nE 's/^name:[[:space:]]*//p' | head -n 1)
  [[ -z "$name" || "$name" == "$dir" ]] || fail "$skill: frontmatter name '$name' differs from directory name '$dir'"
}

check_local_plugin() {
  local entry_name=$1 source=$2
  local dir="${source#./}" pj
  [[ "$source" == ./plugins/* ]] || fail "$entry_name: local source must start with ./plugins/, got '$source'"
  [[ -d "$dir" ]] || {
    fail "$entry_name: directory '$dir' does not exist"
    return
  }
  pj="$dir/.claude-plugin/plugin.json"
  [[ -f "$pj" ]] || {
    fail "$entry_name: '$pj' is missing"
    return
  }
  jq -e . "$pj" >/dev/null 2>&1 || {
    fail "$pj is not valid JSON"
    return
  }
  [[ "$(jq -r '.name // ""' "$pj")" == "$entry_name" ]] || fail "$pj: name must equal marketplace entry name '$entry_name'"
  [[ "$(jq -r '.version // ""' "$pj")" =~ $semver ]] || fail "$pj: version must be semver"
  [[ "$(jq -r '.description // ""' "$pj")" != "" ]] || fail "$pj: description is required"
  [[ "$(jq -r '.license // ""' "$pj")" != "" ]] || fail "$pj: license is required"
  [[ -f "$dir/CHANGELOG.md" ]] || fail "$entry_name: CHANGELOG.md is required in the plugin directory"
  local content=0 skill
  for sub in skills commands agents hooks; do
    [[ -e "$dir/$sub" ]] && content=1
  done
  [[ "$content" == 1 ]] || fail "$entry_name: plugin has no skills, commands, agents or hooks"
  while IFS= read -r skill; do
    check_skill "$skill"
  done < <(find "$dir/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null)
  if [[ "$dir" == plugins/third-party/* ]]; then
    [[ -f "catalog/$entry_name.md" ]] || fail "$entry_name: vendored plugin needs catalog/$entry_name.md"
    ls "$dir"/LICENSE* >/dev/null 2>&1 || fail "$entry_name: vendored plugin must keep its upstream LICENSE file"
  fi
}

check_pinned_plugin() {
  local entry_name=$1 entry=$2
  local kind sha version record
  kind=$(jq -r '.source.source // ""' <<<"$entry")
  case "$kind" in
    github | url | git-subdir) ;;
    *) fail "$entry_name: pinned source kind '$kind' is not allowed (use github, url or git-subdir)" ;;
  esac
  sha=$(jq -r '.source.sha // ""' <<<"$entry")
  [[ "$sha" =~ $sha40 ]] || fail "$entry_name: pinned entries need a 40-character source.sha"
  version=$(jq -r '.version // ""' <<<"$entry")
  [[ "$version" != "" ]] || fail "$entry_name: pinned entries need a version so updates are detected"
  record="catalog/$entry_name.md"
  [[ -f "$record" ]] || {
    fail "$entry_name: pinned plugin needs $record"
    return
  }
  grep -q "$sha" "$record" || fail "$record: does not mention upstream commit $sha"
}

declare -A listed=()
while IFS= read -r entry; do
  name=$(jq -r '.name // ""' <<<"$entry")
  [[ "$name" =~ $kebab ]] || fail "marketplace entry name '$name' is not kebab-case"
  [[ "$name" == "" || -z "${listed[$name]:-}" ]] || fail "marketplace entry '$name' is listed twice"
  listed[$name]=1
  [[ "$(jq -r '.description // ""' <<<"$entry")" != "" ]] || fail "$name: marketplace entry needs a description"
  if [[ "$(jq -r '.source | type' <<<"$entry")" == "string" ]]; then
    [[ "$(jq -r 'has("version")' <<<"$entry")" == "false" ]] || fail "$name: set version in plugin.json only, not in the marketplace entry"
    check_local_plugin "$name" "$(jq -r '.source' <<<"$entry")"
  else
    check_pinned_plugin "$name" "$entry"
  fi
done < <(jq -c '.plugins[]' "$manifest")

# Every plugin directory must be listed.
for dir in plugins/*/ plugins/third-party/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  [[ "$name" == "third-party" ]] && continue
  [[ -n "${listed[$name]:-}" ]] || fail "plugins directory '$dir' is not listed in $manifest"
done

# Every catalog record must belong to a listed third-party plugin.
for record in catalog/*.md; do
  name=$(basename "$record" .md)
  [[ "$name" == "README" || "$name" == "TEMPLATE" ]] && continue
  [[ -n "${listed[$name]:-}" ]] || fail "$record has no matching marketplace entry"
done

if ((errors > 0)); then
  echo "validate-marketplace: $errors error(s)" >&2
  exit 1
fi
echo "validate-marketplace: ok"
