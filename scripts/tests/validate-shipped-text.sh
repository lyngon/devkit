#!/usr/bin/env bash
# Exercise validate-shipped-text.py against throwaway marketplaces: skill
# references that name no skill, in every kind of shipped text, the text of the
# same shape that is no skill reference, and a writing plugin that names
# another plugin's skill or a term of a development repository. Run through
# `devenv test`.
set -euo pipefail

validator=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/validate-shipped-text.py
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
  echo '{"name": "test", "owner": {"name": "t"}, "plugins": []}' >"$repo/.claude-plugin/marketplace.json"
  echo "$repo"
}

# entry <repo> <entry as JSON>: one more plugin in marketplace.json.
entry() {
  local manifest="$1/.claude-plugin/marketplace.json" listed
  listed=$(jq --argjson entry "$2" '.plugins += [$entry]' "$manifest")
  printf '%s\n' "$listed" >"$manifest"
}

# plugin <repo> <name>: a local plugin with one skill, `main`, and a README.
plugin() {
  local repo=$1 name=$2 dir="$1/plugins/$2"
  mkdir -p "$dir/.claude-plugin" "$dir/skills/main"
  printf '{"name": "%s"}\n' "$name" >"$dir/.claude-plugin/plugin.json"
  printf '# %s\n' "$name" >"$dir/README.md"
  printf -- '---\nname: main\ndescription: Test skill.\n---\n\n# Main\n' >"$dir/skills/main/SKILL.md"
  entry "$repo" "{\"name\": \"$name\", \"source\": \"./plugins/$name\"}"
}

# pinned <repo> <name>: a third-party plugin, of which the tree holds no file.
pinned() {
  entry "$1" "{\"name\": \"$2\", \"source\": {\"source\": \"github\", \"repo\": \"example/$2\"}}"
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
  if [[ "$output" == "validate-shipped-text: ok" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_error <label> <repo> <fragment> [<count>]: the run fails and mentions
# the fragment, with that many errors in all when a count is given.
expect_error() {
  local label=$1 repo=$2 fragment=$3 count=${4:-[0-9]+} output
  output=$(run_validator "$repo")
  if grep -qF -- "$fragment" <<<"$output" && grep -qE "^validate-shipped-text: $count error" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected an error containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Skill references --------------------------------------------------------

no_plugin="if this is not a skill, write it another way or add its left side to NAMESPACES in scripts/validate-shipped-text.py"

repo=$(new_repo)
plugin "$repo" one
plugin "$repo" two
echo "Invoke two:main first, then /one:main." >>"$(skill "$repo" one)"
expect_ok "references to skills that exist, in the plugin and in another" "$repo"

repo=$(new_repo)
plugin "$repo" one
echo "Invoke one:gone first." >>"$(skill "$repo" one)"
expect_error "skill that its plugin does not have" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'one:gone', and plugins/one/skills/gone/SKILL.md does not exist"

repo=$(new_repo)
plugin "$repo" one
echo "Write the test first, as practice:tdd says." >>"$(skill "$repo" one)"
expect_error "skill of a plugin that the marketplace does not have" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'practice:tdd', and the marketplace has no plugin 'practice'; $no_plugin"

repo=$(new_repo)
plugin "$repo" one
echo "Run /one:gone when the branch is done." >>"$(skill "$repo" one)"
expect_error "slash command of a skill that does not exist" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
printf -- '---\nname: main\ndescription: Not for a plan (that is one:gone).\n---\n\n# Main\n' >"$(skill "$repo" one)"
expect_error "stale reference in a description" "$repo" "plugins/one/skills/main/SKILL.md:3: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
echo "Then one:gone, and one:gone again, or two:main." >>"$(skill "$repo" one)"
expect_error "every stale reference of a line is reported" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'two:main', and the marketplace has no plugin 'two'" 3

repo=$(new_repo)
plugin "$repo" one
mkdir "$repo/plugins/one/skills/main/references"
echo "See one:gone." >"$repo/plugins/one/skills/main/references/method.md"
expect_error "stale reference in a reference file" "$repo" "plugins/one/skills/main/references/method.md:1: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
mkdir "$repo/plugins/one/skills/main/scripts"
printf '#!/usr/bin/env bash\necho "continue with one:gone"\n' >"$repo/plugins/one/skills/main/scripts/next"
expect_error "stale reference in a script beside a skill" "$repo" "plugins/one/skills/main/scripts/next:2: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
mkdir "$repo/plugins/one/hooks"
echo "Invoke one:gone before any work." >"$repo/plugins/one/hooks/session-start.txt"
expect_error "stale reference in a hook text" "$repo" "plugins/one/hooks/session-start.txt:1: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
mkdir "$repo/plugins/one/agents"
echo "Read the text of one:gone in full." >"$repo/plugins/one/agents/implementer.md"
expect_error "stale reference in an agent file" "$repo" "plugins/one/agents/implementer.md:1: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
plugin "$repo" two
echo "The flow starts with one:gone." >"$repo/shared/FLOW.md"
ln -s ../../../../shared/FLOW.md "$repo/plugins/one/skills/main/FLOW.md"
ln -s ../../../../shared/FLOW.md "$repo/plugins/two/skills/main/FLOW.md"
expect_error "stale reference in a shared document, reported once whatever links it" "$repo" "shared/FLOW.md:1: names the skill 'one:gone'" 1

repo=$(new_repo)
plugin "$repo" one
echo "The flow starts with one:gone." >"$repo/shared/FLOW.md"
expect_error "stale reference in a shared document that nothing links" "$repo" "shared/FLOW.md:1: names the skill 'one:gone'"

repo=$(new_repo)
plugin "$repo" one
echo "Used with one:gone." >>"$repo/plugins/one/README.md"
mkdir -p "$repo/plugins/one/evals/names-it"
echo "Invoke one:gone." >"$repo/plugins/one/evals/names-it/prompt.md"
echo "Copyright one:gone." >"$repo/shared/LICENSE-origin"
ln -s ../../shared/LICENSE-origin "$repo/plugins/one/LICENSE-origin"
expect_ok "a README, an eval case and a license are not shipped text" "$repo"

repo=$(new_repo)
plugin "$repo" one
pinned "$repo" creator
echo "Hand the design to creator:draft." >>"$(skill "$repo" one)"
expect_ok "skill of a pinned plugin, which the tree cannot resolve" "$repo"

# The text of the same shape as a skill reference that the plugins hold.
repo=$(new_repo)
plugin "$repo" one
cat >>"$(skill "$repo" one)" <<'EOF'
Cite the place as file:line, as in src/recovery.js:41, db.ts:15-42, index-conversations:1-31 and SKILL.md:7.
Import a Node builtin as a namespace: import * as fs from "node:fs" and "node:module".
Fetch with `git clone --depth 1 --filter=blob:none --sparse`.
Search with `gh issue list --search 'ledger in:title,body,comments'`.
The input is `url: github:cachix/devenv-nixpkgs/rolling`, or github:lyngon/devkit.
At 2026-09-23T13:10:05 the ratio was 1:1 and the pin sha256:5891b5b5.
The first 22 characters are ${out:0:22}, and the task is devenv:enterShell.
Namespace a skill call as `<plugin>:<skill>`; see https://example.com/one:gone/two.
A key: value pair has a space, and File:line starts with a capital.
EOF
expect_ok "text of the same shape that is no skill reference" "$repo"

repo=$(new_repo)
plugin "$repo" one
echo "Each entry is a key:value pair." >>"$(skill "$repo" one)"
expect_error "pair that is neither a skill nor a listed namespace" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'key:value', and the marketplace has no plugin 'key'; $no_plugin"

repo=$(new_repo)
plugin "$repo" one
plugin "$repo" file
echo "Cite the place as file:line." >>"$(skill "$repo" one)"
expect_error "namespace that a plugin of the marketplace takes" "$repo" "plugins/one/skills/main/SKILL.md:7: names the skill 'file:line', and plugins/file/skills/line/SKILL.md does not exist"

repo=$(new_repo)
plugin "$repo" one
printf 'A binary: \xff\xfe\x00 one:gone\n' >"$repo/plugins/one/skills/main/logo.png"
expect_ok "file that is not text" "$repo"

# --- writing stands alone ----------------------------------------------------

no_other_plugin="and writing assumes no other plugin, so its text names only its own skills"
no_repository="a term of a Lyngon development repository, and writing assumes nothing about the repository it is installed in"

repo=$(new_repo)
plugin "$repo" writing
plugin "$repo" one
echo "Run writing:main on the prose, then read it aloud." >>"$(skill "$repo" writing)"
echo "Terms are in CONCEPTS.md, and the full check is devenv test." >>"$(skill "$repo" one)"
expect_ok "writing that names its own skill, beside a plugin for development" "$repo"

repo=$(new_repo)
plugin "$repo" writing
plugin "$repo" one
echo "Then invoke one:main." >>"$(skill "$repo" writing)"
expect_error "writing names a skill of another plugin" "$repo" "plugins/writing/skills/main/SKILL.md:7: names the skill 'one:main', $no_other_plugin" 1

repo=$(new_repo)
plugin "$repo" writing
pinned "$repo" creator
echo "Hand the draft to /creator:draft." >>"$(skill "$repo" writing)"
expect_error "writing names a skill of a pinned plugin" "$repo" "plugins/writing/skills/main/SKILL.md:7: names the skill 'creator:draft', $no_other_plugin" 1

repo=$(new_repo)
plugin "$repo" writing
echo "Cite the place as file:line." >>"$(skill "$repo" writing)"
expect_ok "writing holds a pair that is no skill reference" "$repo"

repo=$(new_repo)
plugin "$repo" writing
echo "Use the terms of CONCEPTS.md." >>"$(skill "$repo" writing)"
expect_error "writing names a document of a Lyngon repository" "$repo" "plugins/writing/skills/main/SKILL.md:7: names 'CONCEPTS.md', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
echo "Run devenv test before handing over." >>"$(skill "$repo" writing)"
expect_error "writing names devenv" "$repo" "plugins/writing/skills/main/SKILL.md:7: names 'devenv', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
echo "The prose-lint hook checks the dashes." >>"$(skill "$repo" writing)"
expect_error "writing names a hook of the baseline" "$repo" "plugins/writing/skills/main/SKILL.md:7: names 'prose-lint', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
echo "Each package under libs/ has a README." >>"$(skill "$repo" writing)"
expect_error "writing names a directory of the structure" "$repo" "plugins/writing/skills/main/SKILL.md:7: names 'libs/', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
printf -- '\n## With the Lyngon structure\n\nEach package under libs/ has a README.\n' >>"$(skill "$repo" writing)"
expect_error "no heading makes a term conditional in writing" "$repo" "plugins/writing/skills/main/SKILL.md:10: names 'libs/', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
printf -- '---\nname: main\ndescription: Edit prose, such as a README or CLAUDE.md.\n---\n\n# Main\n' >"$(skill "$repo" writing)"
expect_error "writing names a term in a description" "$repo" "plugins/writing/skills/main/SKILL.md:3: names 'CLAUDE.md', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
mkdir "$repo/plugins/writing/hooks"
echo "Decisions are in docs/decisions/." >"$repo/plugins/writing/hooks/session-start.txt"
expect_error "writing names a term in a hook text" "$repo" "plugins/writing/hooks/session-start.txt:1: names 'docs/decisions', $no_repository" 1

repo=$(new_repo)
plugin "$repo" writing
plugin "$repo" one
echo "The glossary is CONCEPTS.md; settle a term with one:main." >"$repo/shared/FORMAT.md"
ln -s ../../../../shared/FORMAT.md "$repo/plugins/writing/skills/main/FORMAT.md"
ln -s ../../../../shared/FORMAT.md "$repo/plugins/one/skills/main/FORMAT.md"
expect_error "writing links a shared document for development" "$repo" "plugins/writing/skills/main/FORMAT.md:1: names 'CONCEPTS.md', $no_repository" 2

repo=$(new_repo)
plugin "$repo" writing
echo "Terms are in CONCEPTS.md." >>"$repo/plugins/writing/README.md"
expect_ok "the README of writing is not shipped text" "$repo"

if ((failures > 0)); then
  echo "test-validate-shipped-text: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-shipped-text: ok"
