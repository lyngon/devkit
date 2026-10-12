#!/usr/bin/env bash
# Validate the marketplace manifest, every plugin directory, every SKILL.md,
# every catalog record, pinned and vendored, the plugins enabled by the
# settings template of /repo:init, the principles index and the plugins that
# every eval case loads.
# These checks carry the devkit's rules on plugins: the file set of a plugin,
# the commit as the version of a local plugin, a slash command for every skill
# outside conventions, pinning per plugin and vendoring per upstream, the
# bundle and its members without dependencies of their own, documents and
# upstream licenses shared through symlinks into shared/, one line and one
# file per principle, and an eval case that runs with the plugins its plugin
# assumes.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

manifest=.claude-plugin/marketplace.json
errors=0

fail() {
  echo "error: $*" >&2
  errors=$((errors + 1))
}

kebab='^[a-z0-9]+(-[a-z0-9]+)*$'
sha40='^[0-9a-f]{40}$'

# Claude Code gives a plugin with a relative source and no version the first
# 12 characters of the marketplace's commit as its version (measured on Claude
# Code 2.1.283), so every commit on the default branch is a new version of
# every local plugin.
no_version="the commit is the version, and a version field would hold every user on that version until someone changes it"

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

# The frontmatter of a file, without the lines that fence it; nothing when the
# file does not start with one.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$1"
}

check_skill() {
  local skill=$1
  local skilldir dir name
  skilldir=$(dirname "$skill")
  dir=$(basename "$skilldir")
  [[ "$dir" =~ $kebab && ${#dir} -le 64 ]] || fail "$skill: directory name '$dir' is not kebab-case or is longer than 64 characters"
  [[ "$(head -n 1 "$skill")" == "---" ]] || fail "$skill: frontmatter must start on line 1"
  grep -qE '^description:[[:space:]]*[^[:space:]]' "$skill" || fail "$skill: frontmatter needs a non-empty description"
  name=$(sed -n '2,/^---$/p' "$skill" | sed -nE 's/^name:[[:space:]]*//p' | head -n 1)
  if [[ -z "$name" ]]; then
    fail "$skill: frontmatter needs a name equal to the directory name '$dir'"
  elif [[ "$name" != "$dir" ]]; then
    fail "$skill: frontmatter name '$name' differs from directory name '$dir'"
  fi

  # A skill directory holds neither provenance nor a license, vendored or not:
  # both are recorded once per upstream, outside the skill.
  local license
  [[ ! -e "$skilldir/UPSTREAM.md" ]] || fail "$skilldir/UPSTREAM.md: a skill directory holds no provenance record; the record of an upstream is catalog/vendored/<upstream>.md"
  for license in "$skilldir"/LICENSE*; do
    [[ -e "$license" || -L "$license" ]] || continue
    fail "$license: a skill directory holds no license file; an upstream license is shared/LICENSE-<upstream>, linked into the plugin's root"
  done
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
  [[ "$(jq -r 'has("version")' "$pj")" == "false" ]] || fail "$pj: a local plugin declares no version: $no_version"
  [[ "$(jq -r '.description // ""' "$pj")" != "" ]] || fail "$pj: description is required"
  [[ "$(jq -r '.license // ""' "$pj")" != "" ]] || fail "$pj: license is required"
  [[ ! -e "$dir/CHANGELOG.md" ]] || fail "$dir/CHANGELOG.md: a plugin has no changelog: its history is the commits under its path, which 'git log --oneline -- $dir' lists"
  local content=0 skill dep meta
  for sub in skills commands agents hooks; do
    [[ -e "$dir/$sub" ]] && content=1
  done
  # A plugin with dependencies and no components is a bundle.
  if [[ "$content" == 0 && "$(jq -r '.dependencies // [] | length' "$pj")" == 0 ]]; then
    fail "$entry_name: plugin has no skills, commands, agents, hooks or dependencies"
  fi
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    jq -e --arg d "$dep" '.plugins[] | select(.name == $d)' "$manifest" >/dev/null ||
      fail "$pj: dependency '$dep' is not a marketplace entry"
  done < <(jq -r '.dependencies // [] | .[] | if type == "string" then . else .name end' "$pj")
  while IFS= read -r skill; do
    check_skill "$skill"
    meta=$(frontmatter "$skill")
    # Convention skills have no slash command, and their body reaches the agent
    # only when it invokes them, so the description says when to do that. They
    # are the only skills without one: the operator can invoke every other
    # skill, whether or not the agent may start it too.
    if [[ "$entry_name" == conventions ]]; then
      grep -qE '^paths:' <<<"$meta" || fail "$skill: conventions skills need a paths list in the frontmatter"
      grep -qE '^user-invocable:[[:space:]]*false' <<<"$meta" || fail "$skill: conventions skills need user-invocable: false"
      grep -qE '^description:.* Invoke before ' <<<"$meta" || fail "$skill: conventions skills need a description that ends with when to invoke them (Invoke before ...)"
    elif grep -qE '^user-invocable:[[:space:]]*false' <<<"$meta"; then
      fail "$skill: only a conventions skill sets user-invocable: false; the operator can invoke every other skill as a slash command"
    fi
  done < <(find "$dir/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null)
  if [[ -f "catalog/$entry_name.md" ]]; then
    fail "$entry_name: local plugins do not get catalog records; vendored skills are recorded per upstream in catalog/vendored/<upstream>.md"
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
    [[ "$(jq -r 'has("version")' <<<"$entry")" == "false" ]] || fail "$name: the marketplace entry of a local plugin declares no version: $no_version"
    check_local_plugin "$name" "$(jq -r '.source' <<<"$entry")"
  else
    check_pinned_plugin "$name" "$entry"
  fi
done < <(jq -c '.plugins[]' "$manifest")

# The `all` bundle lists every local plugin except the bundles and the ones in
# category `devkit`, which maintain this repository and are useless elsewhere.
# It must exist: Claude Code installs one plugin per command and cannot install
# a whole marketplace, so without the bundle adoption costs one command per
# plugin and every repository's list of enabled plugins drifts.
if [[ ! -f plugins/all/.claude-plugin/plugin.json ]]; then
  fail "plugins/all is missing: Claude Code installs one plugin per command, so a repository installs every plugin through this bundle; create it with every local plugin outside the categories devkit and bundle as its dependencies"
else
  expected=$(jq -r '.plugins[] | select(.source | type == "string") | select(.category != "devkit") | select(.category != "bundle") | .name' "$manifest" | sort)
  actual=$(jq -r '.dependencies // [] | .[] | if type == "string" then . else .name end' plugins/all/.claude-plugin/plugin.json | sort)
  [[ "$expected" == "$actual" ]] || fail "plugins/all: dependencies must be exactly: $(tr '\n' ' ' <<<"$expected")"

  # A member assumes every other member, so its text names their skills, and
  # theirs name its own. Declared, that would be a cycle, and Claude Code's
  # documentation does not say what a cycle of dependencies does. The bundle
  # is what installs the members together.
  while IFS= read -r member; do
    pj="plugins/$member/.claude-plugin/plugin.json"
    jq -e . "$pj" >/dev/null 2>&1 || continue
    [[ "$(jq -r 'has("dependencies")' "$pj")" == "false" ]] ||
      fail "$pj: a member of all declares no dependencies: a member assumes the whole bundle, and members name each other's skills in both directions, which a list of dependencies cannot express"
  done <<<"$actual"
fi

# The settings template of /repo:init enables `all` and every member by name:
# Claude Code does not count a plugin installed with the bundle as enabled
# when it checks what another plugin depends on (seen in Claude Code 2.1.278),
# so the settings do not rely on the bundle to enable its members.
settings_template=plugins/repo/skills/init/references/repo-files.md
if [[ -f plugins/all/.claude-plugin/plugin.json && -f "$settings_template" ]]; then
  marketplace=$(jq -r '.name' "$manifest")
  settings=$(awk '/^## \.claude\/settings\.json$/ { section = 1; next }
    section && /^## / { exit }
    section && /^```json$/ { block = 1; next }
    block && /^```$/ { exit }
    block' "$settings_template")
  if jq -e '.enabledPlugins | type == "object"' <<<"$settings" >/dev/null 2>&1; then
    expected=$(jq -r --arg m "$marketplace" '"all@" + $m, (.dependencies // [] | .[] | (if type == "string" then . else .name end) + "@" + $m)' plugins/all/.claude-plugin/plugin.json | sort)
    actual=$(jq -r '.enabledPlugins | keys[]' <<<"$settings" | sort)
    [[ "$expected" == "$actual" ]] || fail "$settings_template: enabledPlugins in the .claude/settings.json template must be exactly: $(tr '\n' ' ' <<<"$expected")"
  else
    fail "$settings_template: the .claude/settings.json section needs a JSON block with an enabledPlugins object"
  fi
fi

# The principles index and the principle files name the same principles. An
# agent picks a principle by its line in the index and then reads its file, so
# a line without a file, or a file without a line, is a principle nobody can
# apply. A file holds at most 100 lines, so that an agent that reads only the
# start of a reference still reads the whole principle.
principles=plugins/principles/skills/index
if [[ -d plugins/principles && ! -f "$principles/SKILL.md" ]]; then
  fail "$principles/SKILL.md is missing: the principles plugin holds its index there, one line for each file under $principles/references/"
elif [[ -d plugins/principles ]]; then
  principle_line='^- \*\*([a-z0-9]+(-[a-z0-9]+)*)\*\* \((pstack|Lyngon)\)\. .+\. .+\.$'
  declare -A indexed=()
  number=0
  # The second test reads a last line that has no newline.
  while IFS= read -r line || [[ -n "$line" ]]; do
    number=$((number + 1))
    [[ "$line" == "- **"* ]] || continue
    if [[ ! "$line" =~ $principle_line ]]; then
      fail "$principles/SKILL.md:$number: a principle's line has the form '- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.', with the name in kebab-case and pstack or Lyngon as the origin"
      continue
    fi
    name=${BASH_REMATCH[1]}
    [[ -z "${indexed[$name]:-}" ]] || fail "$principles/SKILL.md:$number: principle '$name' is listed twice"
    indexed[$name]=1
    [[ -f "$principles/references/$name.md" ]] || fail "$principles/SKILL.md:$number: principle '$name' has no file $principles/references/$name.md"
  done <"$principles/SKILL.md"
  for file in "$principles"/references/*.md; do
    [[ -f "$file" ]] || continue
    name=$(basename "$file" .md)
    [[ -n "${indexed[$name]:-}" ]] || fail "$file: $principles/SKILL.md has no line for '$name'"
    # Counts a last line without a newline too, which wc -l does not.
    length=$(grep -c '' "$file" || true)
    ((length <= 100)) || fail "$file: is $length lines long, and a principle file holds at most 100"
  done
fi

# An eval case runs with the plugins that its frontmatter names, and with its
# own plugin alone when it names none. A plugin assumes every other plugin of
# the checkout, so its case names the plugins directory, which loads them all.
# `writing` is the exception: it assumes no other plugin, and a case that names
# none proves it. The line is read from the frontmatter of prompt.md, so that
# is the one layout of a case.
while IFS= read -r file; do
  if [[ "$file" == */case.yaml ]]; then
    fail "$file: an eval case is a prompt.md with its graders, never a case.yaml; the plugins a case loads are checked in the frontmatter of prompt.md"
    continue
  fi
  inside=${file#plugins/}
  line=$(frontmatter "$file" | grep -E '^plugins:' || true)
  if [[ "${inside%%/*}" == writing ]]; then
    [[ -z "$line" ]] || fail "$file: an eval case of writing has no 'plugins' line in its frontmatter; writing assumes no other plugin, and a case without the line runs with its own plugin alone"
  else
    # One `..` for each directory between the plugins directory and the case.
    expected="plugins: [\"$(dirname "$inside" | sed -E 's|[^/]+|..|g')\"]"
    [[ "$line" == "$expected" ]] || fail "$file: an eval case loads every plugin of the checkout, so its frontmatter needs the line '$expected'; without it the case runs with its own plugin alone"
  fi
done < <(find plugins -regextype posix-extended -regex 'plugins/[^/]+/evals/.+/(prompt\.md|case\.yaml)' | sort)

# Every plugin directory must be listed.
for dir in plugins/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  [[ -n "${listed[$name]:-}" ]] || fail "plugins directory '$dir' is not listed in $manifest"
done

# Every catalog record directly under catalog/ must belong to a listed pinned
# plugin.
for record in catalog/*.md; do
  name=$(basename "$record" .md)
  [[ "$name" == "README" || "$name" == "TEMPLATE" ]] && continue
  [[ -n "${listed[$name]:-}" ]] || fail "$record has no matching marketplace entry"
done

# A vendored record, catalog/vendored/<upstream>.md, covers what was taken
# from one upstream at one commit. Its table under "What was taken" ends each
# row with a destination, a path in backticks. The upstream license is
# shared/LICENSE-<upstream>, and every plugin that holds a destination, or
# links one that lies in shared/, links the license under that name in its
# root, so that an installed plugin carries the license of the text it holds.
destination_cell="^\`([^\`]+)\`\$"
for record in catalog/vendored/*.md; do
  [[ -f "$record" ]] || continue
  upstream=$(basename "$record" .md)
  [[ "$upstream" == "TEMPLATE" ]] && continue
  grep -qE '^- \*\*Upstream\*\*: ' "$record" || fail "$record: needs an '- **Upstream**:' line"
  grep -qE '^- \*\*Upstream commit\*\*: [0-9a-f]{40}$' "$record" || fail "$record: needs a 40-character '- **Upstream commit**:' line"
  grep -qE '^- \*\*Upstream license\*\*: ' "$record" || fail "$record: needs an '- **Upstream license**:' line"
  grep -qE '^- \*\*Reviewed\*\*: ' "$record" || fail "$record: needs a '- **Reviewed**:' line"
  declare -A holders=()
  rows=0
  # Reads the last cell of every row below the table's header and separator.
  while IFS= read -r cell; do
    rows=$((rows + 1))
    if [[ ! "$cell" =~ $destination_cell ]]; then
      fail "$record: a row under '## What was taken' ends with '$cell', where a destination is a path in backticks"
      continue
    fi
    destination=${BASH_REMATCH[1]}
    [[ -e "$destination" ]] || {
      fail "$record: destination '$destination' does not exist"
      continue
    }
    case "$destination" in
      plugins/*)
        plugin=${destination#plugins/}
        holders[${plugin%%/*}]=1
        ;;
      shared/*)
        while IFS= read -r link; do
          plugin=${link#plugins/}
          holders[${plugin%%/*}]=1
        done < <(find plugins -type l -lname "*/$destination")
        ;;
    esac
  done < <(awk '/^## What was taken$/ { section = 1; next }
    section && /^## / { exit }
    section && /^\|/ && ++row > 2 {
      cell = $0
      sub(/[[:space:]]*\|[[:space:]]*$/, "", cell)
      sub(/^.*\|[[:space:]]*/, "", cell)
      print cell
    }' "$record")
  ((rows > 0)) || fail "$record: needs a table under '## What was taken' whose rows each end with a destination"
  while IFS= read -r plugin; do
    [[ -n "$plugin" ]] || continue
    link="plugins/$plugin/LICENSE-$upstream"
    [[ -L "$link" && "$(readlink -f "$link")" == "$PWD/shared/LICENSE-$upstream" ]] ||
      fail "plugins/$plugin: holds text recorded in $record, so it needs LICENSE-$upstream, a link to shared/LICENSE-$upstream"
  done < <(printf '%s\n' "${!holders[@]}" | sort)
done

# Symlinks under plugins/ must resolve and point into shared/ (dereferenced at install time).
while IFS= read -r link; do
  target=$(readlink -f "$link" || true)
  [[ -n "$target" && -f "$target" ]] || {
    fail "$link: symlink does not resolve to a file"
    continue
  }
  case "$target" in
    "$PWD/shared/"*) ;;
    *) fail "$link: symlink must point into shared/, got $target" ;;
  esac
done < <(find plugins -type l)

# Everything in shared/ must be a regular file that some plugin links to.
for doc in shared/*; do
  [[ -f "$doc" && ! -L "$doc" ]] || fail "$doc: shared/ holds regular files only"
  [[ -n $(find plugins -type l -lname "*/shared/$(basename "$doc")") ]] || fail "$doc: nothing under plugins/ links to it"
done

if ((errors > 0)); then
  echo "validate-marketplace: $errors error(s)" >&2
  exit 1
fi
echo "validate-marketplace: ok"
