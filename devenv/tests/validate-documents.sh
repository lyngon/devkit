#!/usr/bin/env bash
# Exercise validate-documents.py against throwaway fixture repositories: for
# each of its seven rules a tree that fails and one that passes, plus the paths
# it skips and the two ways it is run. Run through `devenv test`.
set -euo pipefail

validator=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/validate-documents.py
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# A person's global ignore file must not decide what the fixtures track.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0

# --- Fixture helpers ---------------------------------------------------------

new_repo() {
  local repo
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  git -C "$repo" init -q
  echo "$repo"
}

# write <repo> <path> [line...]: a file with the given lines.
write() {
  local repo=$1 path=$2
  shift 2
  mkdir -p "$(dirname "$repo/$path")"
  if (($# > 0)); then
    printf '%s\n' "$@" >"$repo/$path"
  else
    : >"$repo/$path"
  fi
}

# lines <count>: that many lines of filler.
lines() {
  local i
  for ((i = 1; i <= $1; i++)); do
    echo "Line $i."
  done
}

record() {
  write "$1" "$2" "# Orders are event sourced" "" "The audit needs every change, so orders are stored as events." "" "Enforced by: judgment"
}

# A repository that holds every steering document in its allowed shape.
clean_repo() {
  local repo
  repo=$(new_repo)
  # The agent file holds the import and what the authors added below it.
  write "$repo" INTENT.md "# Intent" "" "## Product" "" "## For whom" "" "## Done means" "" "## Failure means" "" \
    "## Non-goals" "" "## Priorities" "" "- Correct totals over fast checkout." "" "## Horizon"
  write "$repo" .claude/CLAUDE.md "@../INTENT.md" "" "Run the tide simulator before changing the table."
  write "$repo" .claude/rules/money-is-never-a-float.md "# Money is never a float" "" "Amounts are integers of the minor unit." "" "Why: rounding."
  write "$repo" CONCEPTS.md "# Orders"
  write "$repo" README.md "# Orders"
  record "$repo" docs/decisions/orders-are-event-sourced.md
  record "$repo" libs/orders/docs/decisions/orders-are-event-sourced.md
  write "$repo" libs/orders/INTENT.md "# Intent" "" "## Non-goals"
  write "$repo" libs/orders/README.md "# orders"
  echo "$repo"
}

# --- Assertions --------------------------------------------------------------

# run_validator <repo> [path...]: stage everything, then run from the root.
run_validator() {
  local repo=$1
  shift
  git -C "$repo" add -A
  (cd "$repo" && python3 "$validator" "$@" 2>&1) || true
}

expect_ok() {
  local label=$1 repo=$2 output
  shift 2
  output=$(run_validator "$repo" "$@")
  if [[ "$output" == "validate-documents: ok" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# expect_error <label> <repo> <count> <fragment> [path...]: the run fails with
# exactly <count> errors and mentions the fragment.
expect_error() {
  local label=$1 repo=$2 count=$3 fragment=$4 output
  shift 4
  output=$(run_validator "$repo" "$@")
  if grep -qF -- "$fragment" <<<"$output" && grep -qxF "validate-documents: $count error(s)" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected $count error(s) containing '$fragment', got:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

# --- Cases -------------------------------------------------------------------

expect_ok "every steering document in its allowed shape" "$(clean_repo)"

# agent-file-imports-intent
expect_error "agent-file-imports-intent: an empty repository has no agent file" "$(new_repo)" 1 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md, so that every session starts from the intent"

repo=$(clean_repo)
rm "$repo/.claude/CLAUDE.md"
expect_error "agent-file-imports-intent: the agent file is missing, whatever paths are given" "$repo" 1 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md" README.md

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "# Tidewatch" "" "See INTENT.md for the purpose."
expect_error "agent-file-imports-intent: the agent file lacks the import" "$repo" 1 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md; what else the file holds is the authors' choice"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "# Tidewatch" "" "Run the tide simulator before changing the table." "" "@../INTENT.md"
expect_ok "agent-file-imports-intent: the import may stand anywhere in the file" "$repo"

repo=$(clean_repo)
git -C "$repo" add -A
git -C "$repo" rm -q --cached .claude/CLAUDE.md
output=$( (cd "$repo" && python3 "$validator" 2>&1) || true)
if grep -qF "error: .claude/CLAUDE.md: agent-file-imports-intent: create it" <<<"$output"; then
  echo "ok: agent-file-imports-intent: an untracked agent file does not count"
else
  echo "FAIL: agent-file-imports-intent: an untracked agent file does not count, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

# no-agents-md
repo=$(clean_repo)
write "$repo" AGENTS.md "# Agents"
expect_error "no-agents-md: a file at the root, whose lines have somewhere to go" "$repo" 1 \
  "error: AGENTS.md: no-agents-md: move what must stay to .claude/CLAUDE.md, below the line @../INTENT.md, or to .claude/rules/<principle>.md with paths: when it concerns part of the tree, and delete the file; Claude Code reads .claude/CLAUDE.md"

repo=$(clean_repo)
write "$repo" .claude/rules/orders-api-owns-no-logic.md "# Orders API owns no logic"
ln -s ../../.claude/rules/orders-api-owns-no-logic.md "$repo/libs/orders/AGENTS.md"
expect_error "no-agents-md: a symlink in a package" "$repo" 1 \
  "error: libs/orders/AGENTS.md: no-agents-md: delete the link; Claude Code reads .claude/CLAUDE.md"

# no-claude-md-outside-dot-claude
repo=$(clean_repo)
write "$repo" CLAUDE.md "# Orders"
expect_error "no-claude-md-outside-dot-claude: a file at the root" "$repo" 1 \
  "error: CLAUDE.md: no-claude-md-outside-dot-claude: move what must stay to .claude/CLAUDE.md, below the line @../INTENT.md, or to .claude/rules/<principle>.md with paths: when it concerns part of the tree, and delete the file"

repo=$(clean_repo)
write "$repo" libs/orders/CLAUDE.md "# orders"
expect_error "no-claude-md-outside-dot-claude: a file in a package" "$repo" 1 \
  "error: libs/orders/CLAUDE.md: no-claude-md-outside-dot-claude:"

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md"
expect_error "no-claude-md-outside-dot-claude: a .claude directory below the root" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md: no-claude-md-outside-dot-claude:"

# no-docs-adr
repo=$(clean_repo)
record "$repo" docs/adr/0001-orders-are-event-sourced.md
record "$repo" docs/adr/0002-postgres-holds-the-write-model.md
expect_error "no-docs-adr: at the root, reported once" "$repo" 1 \
  "error: docs/adr/: no-docs-adr: move each record that passes the admission test to docs/decisions/<decision-in-kebab-case>.md and delete the directory"

repo=$(clean_repo)
record "$repo" libs/orders/docs/adr/0001-orders-are-event-sourced.md
expect_error "no-docs-adr: in a package" "$repo" 1 \
  "error: libs/orders/docs/adr/: no-docs-adr: move each record that passes the admission test to libs/orders/docs/decisions/<decision-in-kebab-case>.md"

repo=$(clean_repo)
mkdir -p "$repo/elsewhere"
record "$repo" elsewhere/0001-orders-are-event-sourced.md
ln -s ../elsewhere "$repo/docs/adr"
expect_error "no-docs-adr: a symlink named docs/adr" "$repo" 1 "error: docs/adr/: no-docs-adr:"

# decision-record-shape
repo=$(clean_repo)
record "$repo" docs/decisions/Orders_are_event_sourced.md
expect_error "decision-record-shape: a name that is not kebab-case" "$repo" 1 \
  "error: docs/decisions/Orders_are_event_sourced.md: decision-record-shape: name the file after its decision, <decision-in-kebab-case>.md"

repo=$(clean_repo)
record "$repo" docs/decisions/0007-orders-are-event-sourced.md
expect_error "decision-record-shape: a numbered name" "$repo" 1 \
  "error: docs/decisions/0007-orders-are-event-sourced.md: decision-record-shape: drop the number from the name; a record is referred to by its decision"

repo=$(clean_repo)
write "$repo" docs/decisions/orders-are-event-sourced.md "# Orders are event sourced" "" "Enforced by: judgment" "" "The audit needs every change."
expect_error "decision-record-shape: Enforced by is not the last line" "$repo" 1 \
  "error: docs/decisions/orders-are-event-sourced.md: decision-record-shape: end the record with the line 'Enforced by: <name of the check>' or 'Enforced by: judgment'"

repo=$(clean_repo)
write "$repo" docs/decisions/orders-are-event-sourced.md "# Orders are event sourced" "" "Status: accepted" "" "Enforced by: judgment"
expect_error "decision-record-shape: a Status line" "$repo" 1 \
  "error: docs/decisions/orders-are-event-sourced.md:3: decision-record-shape: delete the Status line; a record exists only while its decision holds"

repo=$(clean_repo)
write "$repo" docs/decisions/orders-are-event-sourced.md "# Orders are event sourced" "" "## Change log" "" "- 2026-01-01: reworded." "" "Enforced by: judgment"
expect_error "decision-record-shape: a change log" "$repo" 1 \
  "error: docs/decisions/orders-are-event-sourced.md:3: decision-record-shape: delete the change log; git holds the history of a record"

# intent-shape
repo=$(clean_repo)
write "$repo" INTENT.md "# Intent" "$(lines 49)"
expect_ok "intent-shape: 50 lines" "$repo"

repo=$(clean_repo)
write "$repo" INTENT.md "# Intent" "$(lines 50)"
expect_error "intent-shape: 51 lines" "$repo" 1 \
  "error: INTENT.md: intent-shape: 51 lines; cut it to 50 at most"

repo=$(clean_repo)
write "$repo" libs/orders/INTENT.md "# Intent" "" "## Roadmap"
expect_error "intent-shape: a heading outside the sections, in a package" "$repo" 1 \
  "error: libs/orders/INTENT.md:3: intent-shape: '## Roadmap' is not a section of INTENT.md; use Product, For whom, Done means, Failure means, Non-goals, Priorities or Horizon, or move the text out"

# rule-file-shape
repo=$(clean_repo)
write "$repo" .claude/rules/Money_Rule.md "# Money"
expect_error "rule-file-shape: a name that is not kebab-case" "$repo" 1 \
  "error: .claude/rules/Money_Rule.md: rule-file-shape: name the file after its principle, <principle-in-kebab-case>.md"

repo=$(clean_repo)
write "$repo" .claude/rules/money-is-never-a-float.md "# Money is never a float" "$(lines 99)"
expect_ok "rule-file-shape: 100 lines" "$repo"

repo=$(clean_repo)
write "$repo" .claude/rules/money-is-never-a-float.md "# Money is never a float" "$(lines 100)"
expect_error "rule-file-shape: 101 lines" "$repo" 1 \
  "error: .claude/rules/money-is-never-a-float.md: rule-file-shape: 101 lines; cut it to 100 at most"

# What it looks at
repo=$(clean_repo)
write "$repo" vendor/skills/AGENTS.md "# Agents"
write "$repo" libs/orders/generated/CLAUDE.md "# Generated"
write "$repo" libs/orders/vendor/docs/adr/0001-copied.md "# Copied"
expect_ok "vendor/ and generated/ directories are skipped" "$repo"

repo=$(clean_repo)
git -C "$repo" add -A
write "$repo" AGENTS.md "# Agents"
output=$( (cd "$repo" && python3 "$validator" 2>&1) || true)
if [[ "$output" == "validate-documents: ok" ]]; then
  echo "ok: an untracked file is not looked at"
else
  echo "FAIL: an untracked file is not looked at: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

repo=$(clean_repo)
write "$repo" AGENTS.md "# Agents"
write "$repo" CLAUDE.md "# Orders"
expect_error "given paths, it checks those and no others" "$repo" 1 "error: CLAUDE.md: no-claude-md-outside-dot-claude:" CLAUDE.md README.md
expect_error "given no paths, it checks every tracked file" "$repo" 2 "error: AGENTS.md: no-agents-md:"

repo=$(clean_repo)
write "$repo" AGENTS.md "# Agents"
git -C "$repo" add -A
rm "$repo/AGENTS.md"
output=$( (cd "$repo" && python3 "$validator" 2>&1) || true)
if [[ "$output" == "validate-documents: ok" ]]; then
  echo "ok: a tracked file already deleted from the working tree is not reported"
else
  echo "FAIL: a tracked file already deleted from the working tree is not reported: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

repo=$(clean_repo)
write "$repo" CLAUDE.md "# Orders"
git -C "$repo" add -A
output=$( (cd "$repo/libs/orders" && python3 "$validator" ../../CLAUDE.md 2>&1) || true)
if grep -qF "error: CLAUDE.md: no-claude-md-outside-dot-claude:" <<<"$output"; then
  echo "ok: a path given from a subdirectory is reported relative to the root"
else
  echo "FAIL: a path given from a subdirectory is reported relative to the root, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

# expect_refusal <label> <directory> <fragment> [path...]: the run exits 2,
# says why, and does not claim that anything passed.
expect_refusal() {
  local label=$1 directory=$2 fragment=$3 output code=0
  shift 3
  output=$(cd "$directory" && python3 "$validator" "$@" 2>&1) || code=$?
  if ((code == 2)) && grep -qF -- "$fragment" <<<"$output" && ! grep -qF "validate-documents: ok" <<<"$output"; then
    echo "ok: $label"
  else
    echo "FAIL: $label: expected exit 2 with '$fragment', got exit $code:" && echo "  ${output//$'\n'/$'\n'  }"
    failures=$((failures + 1))
  fi
}

plain=$(mktemp -d "$tmp/plain.XXXXXX")
expect_refusal "outside a git repository, given no paths, it refuses" "$plain" \
  "validate-documents: not inside a git repository, so no tracked files to check; pass the files as arguments"

repo=$(clean_repo)
write "$plain" AGENTS.md "# Agents"
expect_refusal "a path outside the repository is refused" "$repo" \
  "validate-documents: $plain/AGENTS.md is outside the repository" "$plain/AGENTS.md"

if ((failures > 0)); then
  echo "test-validate-documents: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-documents: ok"
