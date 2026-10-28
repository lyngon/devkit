#!/usr/bin/env bash
# Check that the commit hooks validate-marketplace and validate-shipped-text
# judge a commit by what it holds (issue 94). Each case commits a throwaway
# marketplace whose hook configuration holds the two hooks as this
# repository's configuration defines them, then makes a partial commit through
# prek beside untracked files: an untracked file that would fail a check
# leaves the commit alone, and a staged file that needs an untracked one fails
# it. Run through `devenv test`.
#
# Usage: validators-check-the-commit.sh <prek> <hook configuration>
set -euo pipefail

usage="usage: validators-check-the-commit.sh <prek> <hook configuration>"
prek=${1:?$usage}
configuration=${2:?$usage}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# Neither the git configuration nor the hook cache of whoever runs the test.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PREK_HOME="$tmp/prek"
failures=0

# The two hooks as this repository defines them, in a configuration of their
# own. The generated file opens with comment lines, which JSON does not allow.
hooks=$(grep -v '^#' "$configuration" | jq '{repos: [{repo: "local", hooks: [.repos[].hooks[]
  | select(.id == "validate-marketplace" or .id == "validate-shipped-text")]}]}')
if [[ $(jq '.repos[0].hooks | length' <<<"$hooks") != 2 ]]; then
  echo "FAIL: $configuration defines the hooks validate-marketplace and validate-shipped-text not once each" >&2
  exit 1
fi

# --- Fixture helpers ---------------------------------------------------------

# skill <repo> <plugin> <skill> [<line>...]: a skill with those lines below
# its heading.
skill() {
  local repo=$1 plugin=$2 name=$3
  shift 3
  mkdir -p "$repo/plugins/$plugin/skills/$name"
  {
    printf -- '---\nname: %s\ndescription: Test skill.\n---\n\n# %s\n' "$name" "$name"
    (($# == 0)) || printf '\n%s\n' "$@"
  } >"$repo/plugins/$plugin/skills/$name/SKILL.md"
}

# plugin_manifest <repo> <plugin> [<dependency>...]
plugin_manifest() {
  local repo=$1 name=$2 deps=""
  shift 2
  if (($# > 0)); then
    deps=$(printf '"%s",' "$@")
    deps=", \"dependencies\": [${deps%,}]"
  fi
  mkdir -p "$repo/plugins/$name/.claude-plugin"
  printf '{"name": "%s", "description": "Test plugin.", "license": "Apache-2.0"%s}\n' \
    "$name" "$deps" >"$repo/plugins/$name/.claude-plugin/plugin.json"
}

# A marketplace that passes both checks, committed with the two hooks
# installed: a plugin `one` whose skill `main` links the shared document, the
# principles plugin with one principle, and the bundle `all` over both.
marketplace() {
  local repo index
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q
  git -C "$repo" config user.name Test
  git -C "$repo" config user.email test@example.com
  mkdir -p "$repo/.claude-plugin" "$repo/catalog" "$repo/shared"
  cat >"$repo/.claude-plugin/marketplace.json" <<'EOF'
{"name": "test", "owner": {"name": "t"}, "plugins": [
  {"name": "one", "source": "./plugins/one", "description": "Test plugin."},
  {"name": "principles", "source": "./plugins/principles", "description": "Test plugin."},
  {"name": "all", "source": "./plugins/all", "description": "Test plugin.", "category": "bundle"}
]}
EOF
  echo "# Catalog" >"$repo/catalog/README.md"
  echo "# Shared" >"$repo/shared/SHARED.md"
  plugin_manifest "$repo" one
  skill "$repo" one main
  ln -s ../../../../shared/SHARED.md "$repo/plugins/one/skills/main/SHARED.md"
  plugin_manifest "$repo" principles
  skill "$repo" principles index '- **first-principle** (pstack). When the first applies. The first rule.'
  index=$(principles "$repo")
  mkdir -p "$index/references"
  echo "# First principle" >"$index/references/first-principle.md"
  plugin_manifest "$repo" all one principles
  printf '%s\n' "$hooks" >"$repo/.pre-commit-config.yaml"
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "The marketplace"
  (cd "$repo" && "$prek" install -q)
  echo "$repo"
}

principles() {
  echo "$1/plugins/principles/skills/index"
}

# stage_a_change <repo>: one more line in the skill `main`, staged. The hooks
# run on a commit that touches plugins/.
stage_a_change() {
  echo "One more line." >>"$1/plugins/one/skills/main/SKILL.md"
  git -C "$1" add plugins/one/skills/main/SKILL.md
}

# --- Assertions --------------------------------------------------------------

# expect_commit <label> <repo>: the hooks pass a commit of what is staged.
expect_commit() {
  local label=$1 repo=$2 output
  if output=$(cd "$repo" && git commit -q -m "A change" 2>&1); then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected the hooks to pass the commit, got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_refused <label> <repo> <fragment>: the hooks refuse a commit of what
# is staged, with an error that holds the fragment.
expect_refused() {
  local label=$1 repo=$2 fragment=$3 output
  if output=$(cd "$repo" && git commit -q -m "A change" 2>&1); then
    echo "FAIL: $label: expected the hooks to refuse the commit, it passed:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  elif grep -qF -- "$fragment" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

repo=$(marketplace)
stage_a_change "$repo"
expect_commit "partial commit with nothing untracked" "$repo"

# The case of issue 94, where the commit touched no file of principles.
repo=$(marketplace)
echo "# Second principle" >"$(principles "$repo")/references/second-principle.md"
stage_a_change "$repo"
expect_commit "untracked principle file that no index line names" "$repo"

repo=$(marketplace)
skill "$repo" one draft "Invoke one:gone first."
stage_a_change "$repo"
expect_commit "untracked skill that names a skill that does not exist" "$repo"

repo=$(marketplace)
echo "# Second principle" >"$(principles "$repo")/references/second-principle.md"
echo '- **second-principle** (Lyngon). When the second applies. The second rule.' >>"$(principles "$repo")/SKILL.md"
git -C "$repo" add plugins/principles/skills/index/SKILL.md
expect_refused "staged index line whose principle file is untracked" "$repo" \
  "principle 'second-principle' has no file plugins/principles/skills/index/references/second-principle.md"

repo=$(marketplace)
skill "$repo" one helper
echo "Invoke one:helper first." >>"$repo/plugins/one/skills/main/SKILL.md"
git -C "$repo" add plugins/one/skills/main/SKILL.md
expect_refused "staged skill that names a skill that exists only untracked" "$repo" \
  "names 'one:helper', and neither the skill plugins/one/skills/helper/SKILL.md nor the agent plugins/one/agents/helper.md exists"

repo=$(marketplace)
echo "# Extra" >"$repo/shared/EXTRA.md"
ln -s ../../../../shared/EXTRA.md "$repo/plugins/one/skills/main/EXTRA.md"
git -C "$repo" add plugins/one/skills/main/EXTRA.md
stage_a_change "$repo"
expect_refused "staged link whose target in shared/ is untracked" "$repo" \
  "plugins/one/skills/main/EXTRA.md: symlink does not resolve to a file"

if ((failures > 0)); then
  echo "test-validators-check-the-commit: $failures failure(s)" >&2
  exit 1
fi
echo "test-validators-check-the-commit: ok"
