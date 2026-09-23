#!/usr/bin/env bash
# Render the plugin table in README.md between the plugins:start and
# plugins:end markers, from the marketplace manifest and the plugin
# directories. Exits 1 after rewriting README.md when the table changed, so
# the git hook fails until the regenerated file is staged, like a formatter.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

manifest=.claude-plugin/marketplace.json
readme=README.md
start='<!-- plugins:start -->'
end='<!-- plugins:end -->'

if ! grep -qF "$start" "$readme" || ! grep -qF "$end" "$readme"; then
  echo "error: $readme needs the lines '$start' and '$end'" >&2
  exit 1
fi

render() {
  echo "| Plugin | Skills | Prerequisites | Description |"
  echo "| --- | --- | --- | --- |"
  local entry name description dir skills deps skill prerequisites
  while IFS= read -r entry; do
    name=$(jq -r '.name' <<<"$entry")
    description=$(jq -r '.description' <<<"$entry")
    if [[ "$(jq -r '.source | type' <<<"$entry")" == "string" ]]; then
      dir=$(jq -r '.source' <<<"$entry")
      dir=${dir#./}
      skills=""
      for skill in "$dir"/skills/*/; do
        [[ -d "$skill" ]] || continue
        # Skills with user-invocable: false load by file path and have no slash command.
        if sed -n '2,/^---$/p' "$skill/SKILL.md" | grep -qE '^user-invocable:[[:space:]]*false'; then
          skills+="\`$(basename "$skill")\` (by path), "
        else
          skills+="\`/$name:$(basename "$skill")\`, "
        fi
      done
      skills=${skills%, }
      if [[ -z "$skills" ]]; then
        deps=$(jq -r '.dependencies // [] | map("`" + (if type == "string" then . else .name end) + "`") | join(", ")' "$dir/.claude-plugin/plugin.json")
        skills="bundle of $deps"
      fi
      prerequisites=$(sed -nE 's/^Prerequisites: //p' "$dir/README.md" | head -n 1)
    else
      skills="pinned, see [catalog/$name.md](catalog/$name.md)"
      prerequisites="git"
    fi
    echo "| \`$name\` | $skills | $prerequisites | $description |"
  done < <(jq -c '.plugins[]' "$manifest")
}

table=$(render)
rendered=$(awk -v start="$start" -v end="$end" -v table="$table" '
  $0 == start { print; print table; skip = 1; next }
  $0 == end { skip = 0 }
  !skip { print }
' "$readme")

if [[ "$rendered" != "$(cat "$readme")" ]]; then
  printf '%s\n' "$rendered" >"$readme"
  echo "render-plugin-list: $readme plugin table regenerated; stage it and commit again" >&2
  exit 1
fi
