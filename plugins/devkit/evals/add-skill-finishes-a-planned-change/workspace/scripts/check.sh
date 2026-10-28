#!/usr/bin/env bash
# The full check of the marketplace: every skill is named after its directory,
# every license link of a plugin leads to a file, and no Markdown file holds an
# em dash or an en dash.
set -euo pipefail
shopt -s nullglob

cd "$(dirname "${BASH_SOURCE[0]}")/.."
failures=0

for skill in plugins/*/skills/*/SKILL.md; do
  name=$(sed -n 's/^name: *//p' "$skill" | head -n 1)
  directory=$(basename "$(dirname "$skill")")
  if [[ $name != "$directory" ]]; then
    echo "error: $skill: the name '$name' is not the name of its directory, '$directory'"
    failures=$((failures + 1))
  fi
done

for link in plugins/*/LICENSE-*; do
  if [[ ! -e $link ]]; then
    echo "error: $link: the link leads to no file"
    failures=$((failures + 1))
  fi
done

dashes=$(grep -rn --include='*.md' $'—\|–' . || true)
if [[ -n $dashes ]]; then
  echo "error: a dash that the conventions forbid:"
  echo "$dashes"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "full check failed: $failures error(s)"
  exit 1
fi
echo "full check passed"
