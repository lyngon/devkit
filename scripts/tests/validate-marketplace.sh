#!/usr/bin/env bash
# Exercise validate-marketplace.sh against throwaway marketplaces: a clean
# one, one without the `all` bundle, a member of it that declares
# dependencies, a local plugin with a version or a changelog, skills whose
# frontmatter breaks a rule, the flag that only a conventions skill carries,
# vendored records and license links that break a rule, a principles index
# that disagrees with its files, and eval cases that load the wrong plugins.
# Run through `devenv test`.
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
# shared document and declares no dependencies, or a bundle when dependencies
# are given.
plugin() {
  local repo=$1 name=$2 dir="$1/plugins/$2" deps=""
  shift 2
  mkdir -p "$dir/.claude-plugin"
  if (($# > 0)); then
    deps=$(printf '"%s",' "$@")
    deps=", \"dependencies\": [${deps%,}]"
  else
    mkdir -p "$dir/skills/main"
    printf -- '---\nname: main\ndescription: Test skill.\n---\n\n# Main\n' >"$dir/skills/main/SKILL.md"
    ln -s ../../../../shared/SHARED.md "$dir/skills/main/SHARED.md"
  fi
  printf '{"name": "%s", "description": "Test plugin.", "license": "Apache-2.0"%s}\n' \
    "$name" "$deps" >"$dir/.claude-plugin/plugin.json"
  manifest "$repo"
}

# depend <repo> <name> <dependencies as JSON>: the plugin declares them.
depend() {
  local file="$1/plugins/$2/.claude-plugin/plugin.json" declared
  declared=$(jq --argjson dependencies "$3" '.dependencies = $dependencies' "$file")
  printf '%s\n' "$declared" >"$file"
}

# categorize <repo> <name> <category>: the marketplace entry of the plugin
# gets the category. A later call of `plugin` writes the manifest anew.
categorize() {
  local file="$1/.claude-plugin/marketplace.json" listed
  listed=$(jq --arg name "$2" --arg category "$3" '(.plugins[] | select(.name == $name)).category = $category' "$file")
  printf '%s\n' "$listed" >"$file"
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

# A clean marketplace that holds vendored text: the record of the upstream
# `origin`, whose destinations are the plugin's skill and the shared document,
# the upstream license in shared/ and its link in the plugin's root. The
# record's second table is not the one of what was taken, and the template of
# each kind of record sits beside its records.
vendored_marketplace() {
  local repo
  repo=$(clean_marketplace)
  mkdir -p "$repo/catalog/vendored"
  echo "MIT License" >"$repo/shared/LICENSE-origin"
  ln -s ../../shared/LICENSE-origin "$repo/plugins/one/LICENSE-origin"
  cat >"$(record "$repo")" <<'EOF'
# origin

- **Upstream**: <https://example.com/origin>
- **Upstream commit**: 0123456789abcdef0123456789abcdef01234567
- **Upstream license**: MIT
- **Reviewed**: 2026-01-01 by A Reviewer

## What was taken

| Upstream path | Destination |
| --- | --- |
| `skills/main` | `plugins/one/skills/main` |
| `skills/main/SHARED.md` | `shared/SHARED.md` |

## Local patches

### `plugins/one/skills/main`

| Upstream says | The skill says |
| --- | --- |
| partner | user |
EOF
  echo "# {plugin-name}" >"$repo/catalog/TEMPLATE.md"
  echo "# {upstream}" >"$repo/catalog/vendored/TEMPLATE.md"
  echo "$repo"
}

record() {
  echo "$1/catalog/vendored/origin.md"
}

# add_row <repo> <upstream path> <last cell>: one more row in the record's
# table of what was taken.
add_row() {
  sed -i "/^| \`skills\/main\` /a | \`$2\` | $3 |" "$(record "$1")"
}

# A clean marketplace that also holds the principles plugin: an index of two
# principles, one of each origin, with their files. The second file is 100
# lines long, the longest a principle file may be.
principles_marketplace() {
  local repo index
  repo=$(clean_marketplace)
  plugin "$repo" principles
  plugin "$repo" all one principles
  index=$(principles "$repo")
  mkdir -p "$index/references"
  {
    printf -- '---\nname: index\ndescription: Test index.\n---\n\n# Principles\n\n'
    echo '- **first-principle** (pstack). When the first applies. The first rule.'
    echo '- **second-principle** (Lyngon). When the second applies. The second rule.'
  } >"$index/SKILL.md"
  echo "# First principle" >"$index/references/first-principle.md"
  lines 100 >"$index/references/second-principle.md"
  echo "$repo"
}

principles() {
  echo "$1/plugins/principles/skills/index"
}

# lines <count>: a Markdown file of that many lines.
lines() {
  local count
  echo "# Second principle"
  for ((count = 1; count < $1; count++)); do
    echo "A line."
  done
}

# A clean marketplace that also holds the conventions plugin, whose skill has
# the frontmatter that a conventions skill needs.
conventions_marketplace() {
  local repo
  repo=$(clean_marketplace)
  plugin "$repo" conventions
  plugin "$repo" all one conventions
  conventions_skill "$repo" "user-invocable: false"
  echo "$repo"
}

# conventions_skill <repo> [<frontmatter line>...]: the skill of the
# conventions plugin, with those lines after its paths.
conventions_skill() {
  local file="$1/plugins/conventions/skills/main/SKILL.md"
  shift
  {
    printf -- '---\nname: main\ndescription: Test conventions. Invoke before editing a test file.\npaths:\n  - "**/*.test"\n'
    (($# == 0)) || printf '%s\n' "$@"
    printf -- '---\n\n# Main\n'
  } >"$file"
}

# A clean marketplace that also holds the writing plugin.
writing_marketplace() {
  local repo
  repo=$(clean_marketplace)
  plugin "$repo" writing
  plugin "$repo" all one writing
  echo "$repo"
}

# eval_case <repo> <plugin> <case> [<frontmatter line>...]: an eval case of the
# plugin, whose prompt.md has those lines as its frontmatter. The case may be
# a path of several directories.
eval_case() {
  local dir="$1/plugins/$2/evals/$3"
  shift 3
  mkdir -p "$dir/graders"
  {
    echo "---"
    (($# == 0)) || printf '%s\n' "$@"
    echo "---"
    echo "Name the service."
  } >"$dir/prompt.md"
  printf -- '---\ntype: regex\npattern: "billing"\n---\n' >"$dir/graders/names-it.md"
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

whole_bundle_assumed="a member of all declares no dependencies: a member assumes the whole bundle, and members name each other's skills in both directions, which a list of dependencies cannot express"

repo=$(clean_marketplace)
plugin "$repo" two
plugin "$repo" all one two
depend "$repo" one '["two"]'
expect_error "member of the all bundle that depends on another member" "$repo" "plugins/one/.claude-plugin/plugin.json: $whole_bundle_assumed"

repo=$(clean_marketplace)
depend "$repo" one '[]'
expect_error "member of the all bundle with an empty list of dependencies" "$repo" "plugins/one/.claude-plugin/plugin.json: $whole_bundle_assumed"

repo=$(clean_marketplace)
plugin "$repo" devkit
depend "$repo" devkit '["one"]'
categorize "$repo" devkit devkit
expect_ok "plugin outside the all bundle that depends on a member" "$repo"

no_version="the commit is the version, and a version field would hold every user on that version until someone changes it"

repo=$(clean_marketplace)
printf '{"name": "one", "version": "0.1.0", "description": "Test plugin.", "license": "Apache-2.0"}\n' >"$repo/plugins/one/.claude-plugin/plugin.json"
expect_error "version in the manifest of a local plugin" "$repo" "plugins/one/.claude-plugin/plugin.json: a local plugin declares no version: $no_version"

repo=$(clean_marketplace)
sed -i 's|"source": "./plugins/one"|&, "version": "0.1.0"|' "$repo/.claude-plugin/marketplace.json"
expect_error "version in the marketplace entry of a local plugin" "$repo" "one: the marketplace entry of a local plugin declares no version: $no_version"

repo=$(clean_marketplace)
echo "# Changelog" >"$repo/plugins/one/CHANGELOG.md"
expect_error "changelog in a plugin directory" "$repo" "plugins/one/CHANGELOG.md: a plugin has no changelog: its history is the commits under its path, which 'git log --oneline -- plugins/one' lists"

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

expect_ok "conventions skill without a slash command" "$(conventions_marketplace)"

repo=$(conventions_marketplace)
conventions_skill "$repo"
expect_error "conventions skill with a slash command" "$repo" "plugins/conventions/skills/main/SKILL.md: conventions skills need user-invocable: false"

repo=$(conventions_marketplace)
conventions_skill "$repo" "user-invocable: true"
expect_error "conventions skill that sets the flag to true" "$repo" "plugins/conventions/skills/main/SKILL.md: conventions skills need user-invocable: false"

slash_command="only a conventions skill sets user-invocable: false; the operator can invoke every other skill as a slash command"

repo=$(clean_marketplace)
printf -- '---\nname: main\ndescription: Test skill.\nuser-invocable: false\n---\n\n# Main\n' >"$(skill "$repo")"
expect_error "skill outside conventions without a slash command" "$repo" "plugins/one/skills/main/SKILL.md: $slash_command"

repo=$(conventions_marketplace)
printf -- '---\nname: main\ndescription: Test skill.\nuser-invocable:   false\n---\n\n# Main\n' >"$(skill "$repo")"
expect_error "skill outside conventions without a slash command, beside conventions" "$repo" "plugins/one/skills/main/SKILL.md: $slash_command"

repo=$(clean_marketplace)
printf -- '---\nname: main\ndescription: Test skill.\nuser-invocable: true\n---\n\n# Main\n\nSet user-invocable: false only in conventions.\n' >"$(skill "$repo")"
expect_ok "skill that sets the flag to true and names it in its body" "$repo"

expect_ok "vendored record with its destinations and license link" "$(vendored_marketplace)"

repo=$(vendored_marketplace)
sed -i '/^- \*\*Upstream\*\*: /d' "$(record "$repo")"
expect_error "vendored record without an upstream" "$repo" "catalog/vendored/origin.md: needs an '- **Upstream**:' line"

repo=$(vendored_marketplace)
sed -i '/^- \*\*Upstream commit\*\*: /d' "$(record "$repo")"
expect_error "vendored record without a commit" "$repo" "catalog/vendored/origin.md: needs a 40-character '- **Upstream commit**:' line"

repo=$(vendored_marketplace)
sed -i 's/^\(- \*\*Upstream commit\*\*: \).*/\10123456/' "$(record "$repo")"
expect_error "vendored record with a commit of 7 characters" "$repo" "catalog/vendored/origin.md: needs a 40-character '- **Upstream commit**:' line"

repo=$(vendored_marketplace)
sed -i '/^- \*\*Upstream license\*\*: /d' "$(record "$repo")"
expect_error "vendored record without a license" "$repo" "catalog/vendored/origin.md: needs an '- **Upstream license**:' line"

repo=$(vendored_marketplace)
sed -i '/^- \*\*Reviewed\*\*: /d' "$(record "$repo")"
expect_error "vendored record without a reviewer" "$repo" "catalog/vendored/origin.md: needs a '- **Reviewed**:' line"

repo=$(vendored_marketplace)
sed -i '/^## What was taken$/,/^## Local patches$/{/^|/d}' "$(record "$repo")"
expect_error "vendored record without a table of what was taken" "$repo" "catalog/vendored/origin.md: needs a table under '## What was taken' whose rows each end with a destination"

repo=$(vendored_marketplace)
add_row "$repo" skills/other "the main skill"
expect_error "row that ends with something other than a path in backticks" "$repo" "catalog/vendored/origin.md: a row under '## What was taken' ends with 'the main skill', where a destination is a path in backticks"

repo=$(vendored_marketplace)
add_row "$repo" skills/other ""
expect_error "row without a destination" "$repo" "catalog/vendored/origin.md: a row under '## What was taken' ends with '', where a destination is a path in backticks"

repo=$(vendored_marketplace)
sed -i "s/\`shared\/SHARED.md\` |\$/|/" "$(record "$repo")"
expect_error "last row without a destination" "$repo" "catalog/vendored/origin.md: a row under '## What was taken' ends with '', where a destination is a path in backticks"

repo=$(vendored_marketplace)
add_row "$repo" skills/gone "\`plugins/one/skills/gone\`"
expect_error "destination that does not exist" "$repo" "catalog/vendored/origin.md: destination 'plugins/one/skills/gone' does not exist"

needs_link="holds text recorded in catalog/vendored/origin.md, so it needs LICENSE-origin, a link to shared/LICENSE-origin"

repo=$(vendored_marketplace)
rm "$repo/plugins/one/LICENSE-origin"
expect_error "plugin that holds a destination without the license link" "$repo" "plugins/one: $needs_link"

repo=$(vendored_marketplace)
rm "$repo/plugins/one/LICENSE-origin"
cp "$repo/shared/LICENSE-origin" "$repo/plugins/one/LICENSE-origin"
expect_error "copy of the license in place of the link" "$repo" "plugins/one: $needs_link"

repo=$(vendored_marketplace)
ln -sf ../../shared/SHARED.md "$repo/plugins/one/LICENSE-origin"
expect_error "license link that points at another shared file" "$repo" "plugins/one: $needs_link"

repo=$(vendored_marketplace)
plugin "$repo" two
plugin "$repo" all one two
expect_error "plugin that links a shared destination without the license link" "$repo" "plugins/two: $needs_link"

repo=$(clean_marketplace)
echo "# main" >"$repo/plugins/one/skills/main/UPSTREAM.md"
expect_error "provenance record in a skill directory" "$repo" "plugins/one/skills/main/UPSTREAM.md: a skill directory holds no provenance record; the record of an upstream is catalog/vendored/<upstream>.md"

no_license="a skill directory holds no license file; an upstream license is shared/LICENSE-<upstream>, linked into the plugin's root"

repo=$(clean_marketplace)
echo "MIT License" >"$repo/plugins/one/skills/main/LICENSE"
expect_error "license file in a skill directory" "$repo" "plugins/one/skills/main/LICENSE: $no_license"

repo=$(clean_marketplace)
echo "MIT License" >"$repo/plugins/one/skills/main/LICENSE-origin"
expect_error "license file named after its upstream in a skill directory" "$repo" "plugins/one/skills/main/LICENSE-origin: $no_license"

repo=$(clean_marketplace)
echo "# {skill-name}" >"$repo/catalog/UPSTREAM-TEMPLATE.md"
expect_error "second template beside the pinned records" "$repo" "catalog/UPSTREAM-TEMPLATE.md has no matching marketplace entry"

expect_ok "principles index and files agree" "$(principles_marketplace)"

repo=$(principles_marketplace)
rm "$(principles "$repo")/references/first-principle.md"
expect_error "principle in the index without a file" "$repo" "plugins/principles/skills/index/SKILL.md:8: principle 'first-principle' has no file plugins/principles/skills/index/references/first-principle.md"

repo=$(principles_marketplace)
echo "# Third principle" >"$(principles "$repo")/references/third-principle.md"
expect_error "principle file without an index line" "$repo" "plugins/principles/skills/index/references/third-principle.md: plugins/principles/skills/index/SKILL.md has no line for 'third-principle'"

repo=$(principles_marketplace)
lines 101 >"$(principles "$repo")/references/second-principle.md"
expect_error "principle file longer than 100 lines" "$repo" "plugins/principles/skills/index/references/second-principle.md: is 101 lines long, and a principle file holds at most 100"

repo=$(principles_marketplace)
echo '- **first-principle** (pstack). When the first applies again. The first rule again.' >>"$(principles "$repo")/SKILL.md"
expect_error "principle listed twice" "$repo" "plugins/principles/skills/index/SKILL.md:10: principle 'first-principle' is listed twice"

form="a principle's line has the form '- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.', with the name in kebab-case and pstack or Lyngon as the origin"

repo=$(principles_marketplace)
echo '- **Third Principle** (pstack). When the third applies. The third rule.' >>"$(principles "$repo")/SKILL.md"
expect_error "index line with a name that is not kebab-case" "$repo" "plugins/principles/skills/index/SKILL.md:10: $form"

repo=$(principles_marketplace)
echo '- **third-principle** (superpowers). When the third applies. The third rule.' >>"$(principles "$repo")/SKILL.md"
expect_error "index line with another origin" "$repo" "plugins/principles/skills/index/SKILL.md:10: $form"

repo=$(principles_marketplace)
echo '- **third-principle** (Lyngon). The third rule alone.' >>"$(principles "$repo")/SKILL.md"
expect_error "index line of one sentence" "$repo" "plugins/principles/skills/index/SKILL.md:10: $form"

repo=$(principles_marketplace)
printf '%s' '- **third-principle** (Lyngon). When the third applies. The third rule.' >>"$(principles "$repo")/SKILL.md"
expect_error "last index line without a newline" "$repo" "plugins/principles/skills/index/SKILL.md:10: principle 'third-principle' has no file plugins/principles/skills/index/references/third-principle.md"

repo=$(principles_marketplace)
printf '%s' "$(lines 101)" >"$(principles "$repo")/references/second-principle.md"
expect_error "principle file of 101 lines without a final newline" "$repo" "plugins/principles/skills/index/references/second-principle.md: is 101 lines long, and a principle file holds at most 100"

repo=$(principles_marketplace)
rm "$(principles "$repo")/SKILL.md"
expect_error "principles plugin without its index" "$repo" "plugins/principles/skills/index/SKILL.md is missing: the principles plugin holds its index there, one line for each file under plugins/principles/skills/index/references/"

whole_bundle='plugins: ["../../.."]'
needs_bundle="an eval case loads every plugin of the checkout, so its frontmatter needs the line"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "runs: 1" "$whole_bundle" "allowed_tools: [Read, Skill]"
expect_ok "eval case that loads the whole bundle" "$repo"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "runs: 1"
expect_error "eval case without a plugins line" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service
expect_error "eval case with an empty frontmatter" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service
printf 'Name the service.\n\n---\n%s\n---\n' "$whole_bundle" >"$repo/plugins/one/evals/names-the-service/prompt.md"
expect_error "eval case whose plugins line is in the prompt, not the frontmatter" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service 'plugins: ["../.."]'
expect_error "eval case that loads its own plugin by name" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service 'plugins: ["../../..", "../../../../elsewhere"]'
expect_error "eval case that loads a second directory" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "plugins:" '  - "../../.."'
expect_error "eval case with its plugins as a block list" "$repo" "plugins/one/evals/names-the-service/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" all installs-everything "runs: 1"
expect_error "eval case of the bundle without a plugins line" "$repo" "plugins/all/evals/installs-everything/prompt.md: $needs_bundle '$whole_bundle'"

repo=$(clean_marketplace)
eval_case "$repo" one naming/names-the-service 'plugins: ["../../../.."]'
expect_ok "eval case one directory deeper, with the longer path" "$repo"

repo=$(clean_marketplace)
eval_case "$repo" one naming/names-the-service "$whole_bundle"
expect_error "eval case one directory deeper, with the shorter path" "$repo" "plugins/one/evals/naming/names-the-service/prompt.md: $needs_bundle 'plugins: [\"../../../..\"]'"

repo=$(writing_marketplace)
eval_case "$repo" writing plain-words "runs: 1"
eval_case "$repo" one names-the-service "$whole_bundle"
expect_ok "eval case of writing that names no plugin" "$repo"

repo=$(writing_marketplace)
eval_case "$repo" writing plain-words "runs: 1" "$whole_bundle"
expect_error "eval case of writing that loads the whole bundle" "$repo" "plugins/writing/evals/plain-words/prompt.md: an eval case of writing has no 'plugins' line in its frontmatter"

repo=$(writing_marketplace)
eval_case "$repo" writing plain-words 'plugins: [".."]'
expect_error "eval case of writing that names any plugin" "$repo" "plugins/writing/evals/plain-words/prompt.md: an eval case of writing has no 'plugins' line in its frontmatter"

only_context="and a case.yaml holds only schema_version, name and context"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf '# The code the case reads.\nschema_version: "1.1"\nname: names-the-service\ncontext:\n  scaffold_script: seed-workspace.sh\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_ok "case.yaml beside a prompt.md that seeds the run" "$repo"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf 'schema_version: "1.1"\nname: names-another-service\ncontext:\n  scaffold_script: seed-workspace.sh\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml beside a prompt.md under another name than its directory" "$repo" "plugins/one/evals/names-the-service/case.yaml: needs the line 'name: names-the-service'"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf '\n# Indented as a whole.\n  schema_version: "1.1"\n  name: names-the-service\n  plugins: [".."]\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml beside a prompt.md whose keys are indented" "$repo" "plugins/one/evals/names-the-service/case.yaml: starts with an indented line"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf 'schema_version: "1.1"\nname: names-the-service\nexecution:\n  prompt: Name the service.\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml beside a prompt.md that holds a prompt" "$repo" "plugins/one/evals/names-the-service/case.yaml: holds 'execution', $only_context"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf 'schema_version: "1.1"\nname: names-the-service\nplugins: [".."]\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml beside a prompt.md that names plugins" "$repo" "plugins/one/evals/names-the-service/case.yaml: holds 'plugins', $only_context"

repo=$(clean_marketplace)
eval_case "$repo" one names-the-service "$whole_bundle"
printf '{schema_version: "1.1", name: names-the-service, plugins: [".."]}\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml beside a prompt.md that is one flow mapping" "$repo" "plugins/one/evals/names-the-service/case.yaml: holds '{schema_version', $only_context"

repo=$(clean_marketplace)
mkdir -p "$repo/plugins/one/evals/names-the-service"
printf 'schema_version: "1.1"\nname: names-the-service\ncontext:\n  scaffold_script: seed-workspace.sh\n' >"$repo/plugins/one/evals/names-the-service/case.yaml"
expect_error "case.yaml on its own" "$repo" "plugins/one/evals/names-the-service/case.yaml: an eval case is a prompt.md with its graders; a case.yaml only stands beside one"

if ((failures > 0)); then
  echo "test-validate-marketplace: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-marketplace: ok"
