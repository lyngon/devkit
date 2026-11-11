#!/usr/bin/env bash
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

# mistake <repo> <path> [line...]: a file of the mistake ledger whose heading
# is followed by the given lines, which is where its date and its link go.
mistake() {
  local repo=$1 path=$2
  shift 2
  write "$repo" "$path" "# A generated client was edited by hand" "" "$@" "" \
    "The agent edited the client where it should have changed the schema."
}

caught_in="- **Caught in**: [feat(orders): add the client](https://example.com/orders/pull/7)"

# A repository that holds every steering document in its allowed shape.
clean_repo() {
  local repo
  repo=$(new_repo)
  write "$repo" INTENT.md "# Intent" "" "## Product" "" "## For whom" "" "## Done means" "" "## Failure means" "" \
    "## Non-goals" "" "## Priorities" "" "- Correct totals over fast checkout." "" "## Horizon"
  write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../CONCEPTS.md"
  write "$repo" .claude/rules/money-is-never-a-float.md "# Money is never a float" "" "Amounts are integers of the minor unit." "" "Why: rounding."
  write "$repo" CONCEPTS.md "# Orders"
  write "$repo" README.md "# Orders"
  record "$repo" docs/decisions/orders-are-event-sourced.md
  mistake "$repo" docs/mistakes/a-generated-client-was-edited-by-hand.md "- **Date**: 2026-10-12" "$caught_in"
  record "$repo" libs/orders/docs/decisions/orders-are-event-sourced.md
  write "$repo" libs/orders/INTENT.md "# Intent" "" "## Non-goals"
  write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md" "" "@../README.md"
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

repo=$(new_repo)
expect_error "agent-file-imports-intent: an empty repository has no agent file" "$repo" 2 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md, so that every session starts from the intent"
expect_error "agent-file-imports-intent: an empty repository has no intent" "$repo" 2 \
  "error: INTENT.md: agent-file-imports-intent: create it with the repository's intent, which .claude/CLAUDE.md imports into every session"

repo=$(clean_repo)
rm "$repo/.claude/CLAUDE.md"
expect_error "agent-file-imports-intent: the agent file is missing, whatever paths are given" "$repo" 1 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md" README.md

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "@../CONCEPTS.md"
expect_error "agent-file-imports-intent: the agent file lacks the import" "$repo" 1 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md, so that every session starts from the intent"

repo=$(clean_repo)
rm "$repo/INTENT.md"
expect_error "agent-file-imports-intent: the intent that the agent file imports is missing, reported once" "$repo" 1 \
  "error: INTENT.md: agent-file-imports-intent: create it with the repository's intent, which .claude/CLAUDE.md imports into every session" \
  README.md

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

expect_ok "agent-file-imports-intent: a package's agent file beside its INTENT.md" "$(clean_repo)" \
  libs/orders/.claude/CLAUDE.md

repo=$(clean_repo)
rm "$repo/libs/orders/.claude/CLAUDE.md"
expect_error "agent-file-imports-intent: a package INTENT.md without its agent file" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md, so that a session loads the package's intent when it works on a file in libs/orders/" \
  libs/orders/INTENT.md
expect_error "agent-file-imports-intent: a deleted package agent file, given alone" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md" \
  libs/orders/.claude/CLAUDE.md
expect_error "agent-file-imports-intent: both halves of the pair given, one of them deleted" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md" \
  libs/orders/INTENT.md libs/orders/.claude/CLAUDE.md

repo=$(clean_repo)
git -C "$repo" add -A
git -C "$repo" rm -q --cached libs/orders/.claude/CLAUDE.md
output=$( (cd "$repo" && python3 "$validator" 2>&1) || true)
if grep -qF "error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it" <<<"$output"; then
  echo "ok: agent-file-imports-intent: an untracked package agent file does not count"
else
  echo "FAIL: agent-file-imports-intent: an untracked package agent file does not count, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "@../README.md"
expect_error "agent-file-imports-intent: a package agent file lacks the import" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md, so that a session loads the package's intent when it works on a file in libs/orders/"

repo=$(clean_repo)
rm "$repo/libs/orders/INTENT.md"
expect_error "agent-file-imports-intent: a deleted package INTENT.md, given alone" "$repo" 1 \
  "error: libs/orders/INTENT.md: agent-file-imports-intent: create it with the sections in which the package's intent differs from the root's, or delete libs/orders/.claude/CLAUDE.md, which a package holds only beside its INTENT.md" \
  libs/orders/INTENT.md

repo=$(clean_repo)
write "$repo" libs/billing/CONCEPTS.md "# Billing"
write "$repo" libs/billing/.claude/CLAUDE.md "@../CONCEPTS.md"
expect_error "agent-file-imports-intent: a core library's agent file that imports only its CONCEPTS.md" "$repo" 1 \
  "error: libs/billing/INTENT.md: agent-file-imports-intent: create it with the sections in which the package's intent differs from the root's, or delete libs/billing/.claude/CLAUDE.md"

repo=$(clean_repo)
write "$repo" tests/fixtures/orders/INTENT.md "# Intent" "" "## Non-goals"
expect_ok "agent-file-imports-intent: a fixture tree that the arguments keep out" "$repo" README.md
expect_error "agent-file-imports-intent: the same fixture tree, given no paths" "$repo" 1 \
  "error: tests/fixtures/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../CONCEPTS.md" "Run the tide simulator before changing the table."
expect_error "agent-file-holds-only-imports: free text at the root" "$repo" 1 \
  "error: .claude/CLAUDE.md:3: agent-file-holds-only-imports: delete the line, or move what it says to .claude/rules/<principle>.md, with paths: when it concerns part of the tree; an agent file holds only lines of the form @../<name>.md"

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "# orders" "" "@../INTENT.md"
expect_error "agent-file-holds-only-imports: a heading in a package" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md:1: agent-file-holds-only-imports: delete the line, or move what it says to .claude/rules/<principle>.md"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../CONCEPTS.md" "@anders please review"
expect_error "agent-file-holds-only-imports: a mention is no import" "$repo" 1 \
  "error: .claude/CLAUDE.md:3: agent-file-holds-only-imports: delete the line,"

repo=$(clean_repo)
write "$repo" "my notes.md" "# Notes"
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../my notes.md"
expect_error "agent-file-holds-only-imports: a name with a space is no import" "$repo" 1 \
  "error: .claude/CLAUDE.md:2: agent-file-holds-only-imports: delete the line,"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../CONCEPTS.md" "@INTENT.md"
expect_error "agent-file-holds-only-imports: an import of a file beside the agent file" "$repo" 1 \
  "error: .claude/CLAUDE.md:3: agent-file-holds-only-imports: '@INTENT.md' imports no Markdown file directly in the root; write it as @../<name>.md, or delete the line"

repo=$(clean_repo)
write "$repo" ruff.toml "[lint]"
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../ruff.toml"
expect_error "agent-file-holds-only-imports: an import of a file that is not Markdown" "$repo" 1 \
  "error: .claude/CLAUDE.md:2: agent-file-holds-only-imports: '@../ruff.toml' imports no Markdown file directly in the root;"

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md" "@../../INTENT.md"
expect_error "agent-file-holds-only-imports: a package agent file imports the root's intent" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md:2: agent-file-holds-only-imports: '@../../INTENT.md' imports no Markdown file directly in libs/orders/; write it as @../<name>.md, or delete the line"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "  @../INTENT.md" "@../CONCEPTS.md"
expect_error "agent-file-holds-only-imports: an indented import is no import" "$repo" 2 \
  "error: .claude/CLAUDE.md:1: agent-file-holds-only-imports: '  @../INTENT.md' imports no Markdown file directly in the root;"
expect_error "agent-file-holds-only-imports: an indented import of the intent leaves the line missing" "$repo" 2 \
  "error: .claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md"

repo=$(clean_repo)
write "$repo" .claude/CLAUDE.md "@../INTENT.md" "@../CONCEPTS.md" "@../GLOSSARY.md"
expect_error "agent-file-holds-only-imports: an import of a missing file at the root" "$repo" 1 \
  "error: .claude/CLAUDE.md:3: agent-file-holds-only-imports: the line imports GLOSSARY.md, which is missing or untracked; add the file, or delete the line"

repo=$(clean_repo)
write "$repo" .gitignore "/libs/orders/NOTES.md"
write "$repo" libs/orders/NOTES.md "# Notes"
write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md" "@../NOTES.md"
expect_error "agent-file-holds-only-imports: an import of an untracked file in a package" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md:2: agent-file-holds-only-imports: the line imports libs/orders/NOTES.md, which is missing or untracked; add the file, or delete the line"

repo=$(clean_repo)
rm "$repo/libs/orders/README.md"
expect_error "agent-file-holds-only-imports: a deleted imported file, given alone" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md:3: agent-file-holds-only-imports: the line imports libs/orders/README.md, which is missing or untracked" \
  libs/orders/README.md

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md" "@../CLAUDE.md"
expect_error "agent-file-holds-only-imports: an imported stray CLAUDE.md, deleted and given alone" "$repo" 1 \
  "error: libs/orders/.claude/CLAUDE.md:2: agent-file-holds-only-imports: the line imports libs/orders/CLAUDE.md, which is missing or untracked" \
  libs/orders/CLAUDE.md

repo=$(clean_repo)
write "$repo" libs/orders/.claude/CLAUDE.md "@../INTENT.md" "Orders are event sourced."
expect_ok "agent-file-holds-only-imports: a file deeper in a package brings in no agent file" "$repo" \
  libs/orders/docs/decisions/orders-are-event-sourced.md

# no-agents-md
repo=$(clean_repo)
write "$repo" AGENTS.md "# Agents"
expect_error "no-agents-md: a file at the root, whose lines have somewhere to go" "$repo" 1 \
  "error: AGENTS.md: no-agents-md: move what must stay to .claude/rules/<principle>.md, with paths: when it concerns part of the tree, and delete the file; Claude Code reads .claude/CLAUDE.md, and no other agent harness is supported"

repo=$(clean_repo)
write "$repo" .claude/rules/orders-api-owns-no-logic.md "# Orders API owns no logic"
ln -s ../../.claude/rules/orders-api-owns-no-logic.md "$repo/libs/orders/AGENTS.md"
expect_error "no-agents-md: a symlink in a package" "$repo" 1 \
  "error: libs/orders/AGENTS.md: no-agents-md: delete the link; Claude Code reads .claude/CLAUDE.md"

# no-claude-md-outside-dot-claude
repo=$(clean_repo)
write "$repo" CLAUDE.md "# Orders"
expect_error "no-claude-md-outside-dot-claude: a file at the root" "$repo" 1 \
  "error: CLAUDE.md: no-claude-md-outside-dot-claude: move what must stay to .claude/rules/<principle>.md, with paths: when it concerns part of the tree, and delete the file"

repo=$(clean_repo)
write "$repo" libs/orders/CLAUDE.md "# orders"
expect_error "no-claude-md-outside-dot-claude: a file in a package" "$repo" 1 \
  "error: libs/orders/CLAUDE.md: no-claude-md-outside-dot-claude:"

repo=$(clean_repo)
write "$repo" .claude/commands/CLAUDE.md "# Commands"
expect_error "no-claude-md-outside-dot-claude: a file in a directory below .claude/" "$repo" 1 \
  "error: .claude/commands/CLAUDE.md: no-claude-md-outside-dot-claude:"

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

# ledger-file-shape
ledger_file=docs/mistakes/a-generated-client-was-edited-by-hand.md

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 2026-10-12"
expect_ok "ledger-file-shape: a mistake whose pull request does not exist yet" "$repo"

repo=$(clean_repo)
mistake "$repo" docs/mistakes/Edited_Client.md "- **Date**: 2026-10-12"
expect_error "ledger-file-shape: a name that is not kebab-case" "$repo" 1 \
  "error: docs/mistakes/Edited_Client.md: ledger-file-shape: name the file after its mistake, docs/mistakes/<mistake-in-kebab-case>.md, with no directory between"

repo=$(clean_repo)
mistake "$repo" docs/mistakes/2026/a-print-call-was-left-in-library-code.md "- **Date**: 2026-10-12"
expect_error "ledger-file-shape: a file in a directory of the ledger" "$repo" 1 \
  "error: docs/mistakes/2026/a-print-call-was-left-in-library-code.md: ledger-file-shape: name the file after its mistake, docs/mistakes/<mistake-in-kebab-case>.md, with no directory between"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 2026-10-12" \
  "- **Caught in**: [fix(orders): accept [] as an empty list](https://example.com/orders/pull/8)"
expect_ok "ledger-file-shape: a pull request title with brackets of its own" "$repo"

repo=$(clean_repo)
write "$repo" "$ledger_file" "The agent edited the client by hand." "" "- **Date**: 2026-10-12"
expect_error "ledger-file-shape: no heading on the first line" "$repo" 1 \
  "error: $ledger_file:1: ledger-file-shape: start the file with the heading '# <the mistake, as a sentence>'"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "$caught_in"
expect_error "ledger-file-shape: no date line" "$repo" 1 \
  "error: $ledger_file: ledger-file-shape: 0 lines '- **Date**: <YYYY-MM-DD>'; give the file exactly one, with the day the mistake was caught, because the ledger is pruned by it"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 2026-10-12" "- **Date**: 2026-10-13"
expect_error "ledger-file-shape: two date lines" "$repo" 1 \
  "error: $ledger_file: ledger-file-shape: 2 lines '- **Date**: <YYYY-MM-DD>'; give the file exactly one"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 12 October 2026"
expect_error "ledger-file-shape: a date in another form" "$repo" 1 \
  "error: $ledger_file:3: ledger-file-shape: '12 October 2026' is no day; write the day the mistake was caught as YYYY-MM-DD"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 2026-02-30"
expect_error "ledger-file-shape: a day that does not exist" "$repo" 1 \
  "error: $ledger_file:3: ledger-file-shape: '2026-02-30' is no day; write the day the mistake was caught as YYYY-MM-DD"

repo=$(clean_repo)
mistake "$repo" "$ledger_file" "- **Date**: 2026-10-12" "- **Caught in**: pull request 7"
expect_error "ledger-file-shape: caught in something that is no link" "$repo" 1 \
  "error: $ledger_file:4: ledger-file-shape: write the line as '- **Caught in**: [<pull request title>](<pull request link>)', or leave it out until the pull request exists"

repo=$(clean_repo)
write "$repo" libs/orders/docs/mistakes/notes.md "Notes on mistakes in the orders library."
expect_ok "ledger-file-shape: only docs/mistakes/ at the root is the ledger" "$repo"

# What it looks at
repo=$(clean_repo)
write "$repo" vendor/skills/AGENTS.md "# Agents"
write "$repo" libs/orders/generated/CLAUDE.md "# Generated"
write "$repo" libs/orders/vendor/docs/adr/0001-copied.md "# Copied"
write "$repo" vendor/skills/INTENT.md "# Intent of a copied skill"
write "$repo" vendor/skills/.claude/CLAUDE.md "Read the skill before you change it."
write "$repo" libs/orders/generated/client/INTENT.md "## Roadmap"
write "$repo" libs/orders/generated/client/.claude/CLAUDE.md "# Generated"
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

python_only=$(mktemp -d "$tmp/python-only.XXXXXX")
ln -s "$(command -v python3)" "$python_only/python3"
untracked=$(mktemp -d "$tmp/untracked.XXXXXX")
write "$untracked" .claude/CLAUDE.md "@../INTENT.md"
write "$untracked" README.md "# Orders"
output=$( (cd "$untracked" && env -i PATH="$python_only" python3 "$validator" README.md 2>&1) || true)
if grep -qxF "error: INTENT.md: agent-file-imports-intent: create it with the repository's intent, which .claude/CLAUDE.md imports into every session" <<<"$output" &&
  grep -qxF "validate-documents: 1 error(s)" <<<"$output"; then
  echo "ok: without git, a file missing from the working tree is missing"
else
  echo "FAIL: without git, a file missing from the working tree is missing, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi
write "$untracked" INTENT.md "# Intent" "" "## Non-goals"
output=$( (cd "$untracked" && env -i PATH="$python_only" python3 "$validator" README.md 2>&1) || true)
if [[ "$output" == "validate-documents: ok" ]]; then
  echo "ok: without git, every file of the working tree counts as tracked"
else
  echo "FAIL: without git, every file of the working tree counts as tracked: expected ok, got:" && echo "  ${output//$'\n'/$'\n'  }"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "test-validate-documents: $failures failure(s)" >&2
  exit 1
fi
echo "test-validate-documents: ok"
