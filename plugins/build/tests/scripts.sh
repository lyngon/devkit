#!/usr/bin/env bash
# Exercise the build plugin's scripts against throwaway git repositories and
# plans. The repository's full check runs this file.
set -euo pipefail

build=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
delegate=$build/skills/delegate/scripts
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

# --- Assertions --------------------------------------------------------------

check() {
  local label=$1
  shift
  if "$@"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

equals() {
  [[ "$1" == "$2" ]] || {
    echo "  expected: $2"
    echo "  actual:   $1"
    return 1
  }
}

contains() {
  grep -qF -- "$2" <<<"$1" || {
    echo "  missing: $2"
    return 1
  }
}

lacks() {
  ! grep -qF -- "$2" <<<"$1" || {
    echo "  unexpected: $2"
    return 1
  }
}

# run <command>...: run a command, capturing stdout, stderr and the exit code
# in out, err and code.
run() {
  code=0
  out=$("$@" 2>"$tmp/stderr" </dev/null) || code=$?
  err=$(<"$tmp/stderr")
}

# new_repo <name>: a git repository with one commit, printed as its path.
new_repo() {
  local repo=$tmp/$1
  mkdir -p "$repo/docs/plans"
  git -C "$repo" init -q -b main
  git -C "$repo" commit -q --allow-empty -m "chore: start"
  echo "$repo"
}

# --- pin ---------------------------------------------------------------------

repo=$(new_repo pin)
printf 'hello\n' >"$repo/artifact.txt"
hello=5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
run bash "$delegate/pin" "$repo/artifact.txt"
check "pin: prints sha256:<hex> and the file" \
  equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/artifact.txt"
check "pin --check: a matching pin exits 0 and prints nothing" \
  equals "$code|$out|$err" "0||"
printf 'hello!\n' >"$repo/edited.txt"
run bash "$delegate/pin" --check "sha256:$hello" "$repo/edited.txt"
check "pin --check: an edited file exits 1 and names both hashes" \
  equals "$code|$(grep -c "pinned sha256:$hello, found sha256:" <<<"$err")" "1|1"
run bash "$delegate/pin" --check "sha256:abc" "$repo/artifact.txt"
check "pin --check: a malformed pin is a usage error" \
  equals "$code" "2"
run bash "$delegate/pin" "$repo/missing.txt"
check "pin: a missing file is an error, with nothing printed" \
  equals "$code|$out" "2|"
for tool in sha256sum shasum; do
  only=$tmp/only-$tool
  mkdir -p "$only"
  ln -s "$(command -v bash)" "$only/bash"
  ln -s "$(command -v "$tool")" "$only/$tool"
  run env -i PATH="$only" "$only/bash" "$delegate/pin" "$repo/artifact.txt"
  check "pin: works with $tool alone" \
    equals "$code|$out" "0|sha256:$hello $repo/artifact.txt"
done
none=$tmp/no-hash-tool
mkdir -p "$none"
ln -s "$(command -v bash)" "$none/bash"
run env -i PATH="$none" "$none/bash" "$delegate/pin" "$repo/artifact.txt"
check "pin: without a hash tool, exits 2 and says so" \
  equals "$code|$err" "2|pin: neither sha256sum nor shasum is on PATH"

# --- review-package ----------------------------------------------------------

repo=$(new_repo review-package)
printf '# Plan\n' >"$repo/docs/plans/2026-01-01-demo.md"
git -C "$repo" add docs/plans/2026-01-01-demo.md
git -C "$repo" commit -q -m "docs: add the plan"
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" commit -q --allow-empty -m "chore: record the apply of demo.tfplan" \
  -m "Gate apply-demo: owner 2026-01-01T10:00:00+0000: \"yes\""
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md "$3" HEAD' _ "$repo" "$delegate" "$base"
package=$(cat "$out" 2>/dev/null || true)
check "review-package: a range holding only an empty record commit makes a package" \
  equals "$code" "0"
check "review-package: the package shows the record commit's evidence" \
  contains "$package" 'Gate apply-demo: owner 2026-01-01T10:00:00+0000: "yes"'
run bash -c 'cd "$1" && bash "$2/review-package" docs/plans/2026-01-01-demo.md HEAD HEAD' _ "$repo" "$delegate"
check "review-package: an empty range is still refused" \
  equals "$code" "3"

# --- task-brief --------------------------------------------------------------

# The fixture's fences are tildes; a copy with backticks proves both kinds.
# Task 1 holds a fenced fake task heading and gate after an inner fence, which
# must stay text; the plan ends with an Execution status after the last task.
fixture() {
  cat <<'EOF'
# Fixture

## Design

Nothing here.

## Plan

### Owner Gates

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| `apply-thing` | 2 | agent | creates the thing | no |

### Global Constraints

- Constraint one.

### Task 1: Ungated

**Files:**

- Create: `a.txt`

- [ ] **Step 1: Write a**

~~~~markdown
~~~bash
### Task 9: Inside an inner fence
~~~
- [ ] **Step 2: Owner gate `fenced-gate`**
~~~~

- [ ] **Step 2: Commit**

### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 1: Plan the thing**

Run: `make-plan > thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

- [ ] **Step 3: Apply**

Run: `apply thing.plan`

- [ ] **Step 4: Record**

### Task 3: Last

- [ ] **Step 1: Finish**

## Execution status

Resume at: Task 2 pre-gate (gate apply-thing)
EOF
}

repo=$(new_repo task-brief)
plan=$repo/docs/plans/2026-01-01-fixture.md
fixture >"$plan"
brief() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$delegate/task-brief" "$@"
  body=$(cat "$out" 2>/dev/null || true)
}

brief "$plan" 1
check "task-brief: an ungated task prints the path of task-1-brief.md" \
  equals "$code|${out##*/}" "0|task-1-brief.md"
check "task-brief: a fenced task heading and gate stay inside the task" \
  contains "$body" "- [ ] **Step 2: Commit**"
check "task-brief: the task stops at the next task" \
  lacks "$body" "### Task 2: Gated"
check "task-brief: the Global Constraints follow the task" \
  equals "$(tail -n 3 <<<"$body")" $'### Global Constraints\n\n- Constraint one.'

fixture | tr '~' '`' >"$repo/docs/plans/2026-01-01-backticks.md"
brief "$repo/docs/plans/2026-01-01-backticks.md" 1
check "task-brief: backtick fences inside a longer backtick fence stay text" \
  equals "$code|$(grep -c 'Step 2: Commit' <<<"$body")" "0|1"

brief "$plan" 2
check "task-brief: a gated task without --part is refused" \
  equals "$code|$err" "3|task-brief: task 2 has owner gate \`apply-thing\`; pass --part pre-gate or --part post-gate"
check "task-brief: a refusal writes no brief" \
  equals "$(compgen -G "$repo/tmp/build/2026-01-01-fixture/task-2*" || true)" ""

brief "$plan" 2 --part pre-gate
check "task-brief: the pre-gate brief is task-2-pre-gate-brief.md" \
  equals "$code|${out##*/}" "0|task-2-pre-gate-brief.md"
check "task-brief: the pre-gate brief holds the header, the pre-gate steps, the gate and the stop line" \
  equals "$(sed -n '1,/^Stop here/p' <<<"$body")" "$(cat <<'EOF'
### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 1: Plan the thing**

Run: `make-plan > thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

Stop here: the controller takes the gate.
EOF
)"
check "task-brief: the pre-gate brief leaves out the post-gate steps" \
  equals "$code|$(grep -c 'Step 3: Apply' <<<"$body")" "0|0"
check "task-brief: the pre-gate brief ends with the Global Constraints" \
  equals "$(tail -n 1 <<<"$body")" "- Constraint one."

brief "$plan" 2 --part post-gate
check "task-brief: the post-gate brief holds the header, the gate and the post-gate steps" \
  equals "$(sed -n '1,/^- \[ \] \*\*Step 4/p' <<<"$body")" "$(cat <<'EOF'
### Task 2: Gated

**Files:**

- Temporary: `thing.plan`

- [ ] **Step 2: Owner gate `apply-thing`**
  - Show: `thing.plan`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, `apply --set key:value thing.plan`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

- [ ] **Step 3: Apply**

Run: `apply thing.plan`

- [ ] **Step 4: Record**
EOF
)"
check "task-brief: the post-gate brief leaves out the pre-gate steps" \
  equals "$code|$(grep -c 'Step 1: Plan the thing' <<<"$body")" "0|0"
check "task-brief: the post-gate brief stops at the next task" \
  equals "$code|$(grep -c 'Task 3: Last' <<<"$body")" "0|0"

brief "$plan" 3
check "task-brief: the last task stops before the Execution status" \
  equals "$code|$(grep -c 'Step 1: Finish' <<<"$body")|$(grep -c 'Resume at:' <<<"$body")" "0|1|0"

brief "$plan" 1 --part pre-gate
check "task-brief: --part on an ungated task is refused" \
  equals "$code|$err" "3|task-brief: task 1 has no owner gate; leave out --part"

check "task-brief: a field value holding a colon and backticks is read by its field name" \
  contains "$(cat "$repo/tmp/build/2026-01-01-fixture/task-2-pre-gate-brief.md")" "  - Performed by: agent, \`apply --set key:value thing.plan\`"

brief "$plan" 1
with_index=$body
fixture | sed '/^### Owner Gates$/,/^### Global Constraints$/{/^### Global Constraints$/!d;}' | sed '/^### Task 2: Gated$/,$d' >"$plan"
brief "$plan" 1
check "task-brief: a plan without an Owner Gates index or a gate extracts its tasks as before" \
  equals "$code|$body" "0|$with_index"

fixture | sed 's/^- \[ \] \*\*Step 2: Owner gate/- [x] **Step 2: Owner gate/' >"$plan"
brief "$plan" 2 --part pre-gate
check "task-brief: a ticked gate step is still a gate" \
  equals "$code|$(grep -c '^- \[x\] \*\*Step 2: Owner gate' <<<"$body")|$(grep -c '^Stop here: the controller takes the gate.$' <<<"$body")" "0|1|1"
fixture >"$plan"

# refused <label> <expected stderr> <sed script>: task 2 of a fixture edited by
# the sed script is refused with exactly that message.
refused() {
  local label=$1 expected=$2 edit=$3
  fixture | sed "$edit" >"$plan"
  brief "$plan" 2 --part pre-gate
  check "task-brief refuses $label" equals "$code|$err" "3|task-brief: $expected"
}
# Each case is three lines: what is refused, the exact message, and the sed
# script that breaks the fixture that way.
while read -r label && read -r expected && read -r edit; do
  refused "$label" "$expected" "$edit"
done <<'EOF'
a second gate in the task
task 2 has 2 owner gates; a task has at most one
s/^- \[ \] \*\*Step 4: Record\*\*$/- [ ] **Step 4: Owner gate `record-thing`**/
a missing field
owner gate `apply-thing`: the field Consequences is missing
/^  - Consequences:/d
a field given twice
owner gate `apply-thing`: the field Ask appears twice
s/^  - On no: .*/  - Ask: "Really?"/
a performer that is neither agent nor owner
owner gate `apply-thing`: Performed by must start with "agent, " or "owner, "
s/^  - Performed by: agent, /  - Performed by: whoever, /
an ID missing from the index
owner gate `apply-thing` is missing from the Owner Gates index
s/^| `apply-thing` |/| `apply-other` |/
an ID that is not kebab-case
owner gate `Apply_Thing`: the ID must be kebab-case
s/Owner gate `apply-thing`/Owner gate `Apply_Thing`/
a duplicate ID
owner gate `apply-thing` appears 2 times in the plan; an ID is unique
s/^- \[ \] \*\*Step 2: Commit\*\*$/- [ ] **Step 2: Owner gate `apply-thing`**/
a malformed marker
task 2: malformed owner gate marker: - [ ] **Step 2: Owner gate apply-thing**
s/^- \[ \] \*\*Step 2: Owner gate `apply-thing`\*\*$/- [ ] **Step 2: Owner gate apply-thing**/
EOF
fixture >"$plan"

brief "$plan" 7
check "task-brief: a missing task exits 3" \
  equals "$code|$err" "3|task-brief: task 7 not found (no heading matching Task 7)"

# --- execution-status --------------------------------------------------------

repo=$(new_repo execution-status)
plan=$repo/docs/plans/2026-01-01-paused.md
printf '# Paused\n\n## Plan\n\n### Task 1: Only\n\n- [ ] **Step 1: Do it**\n' >"$plan"
original=$(cat "$plan")
status() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$delegate/execution-status" "$@"
}
workspace=$(cd "$repo" && bash "$delegate/workspace" "$plan")
ledger=$workspace/progress.md
printf '# build ledger: plan %s\nTask 1 pre-gate: complete (no commits)\n' "$plan" >"$ledger"

status write "$plan" "Task 1 pre-gate (gate do-it)"
check "execution-status write: prints the plan" \
  equals "$code|$out" "0|$plan"
check "execution-status write: appends the section after a blank line" \
  equals "$(cat "$plan")" "$original

## Execution status

The run paused here; \`build:finish\` removes this section with the rest of the plan.
The fence holds the ledger verbatim, and an executor recreates \`progress.md\` from it when its workspace has none.

Resume at: Task 1 pre-gate (gate do-it)

\`\`\`\`text
# build ledger: plan $plan
Task 1 pre-gate: complete (no commits)
\`\`\`\`"

printf 'Gate do-it: waiting for owner\n' >>"$ledger"
status write "$plan" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a second write leaves one section" \
  equals "$(grep -c '^## Execution status' "$plan")" "1"
check "execution-status write: a second write leaves the lines before the section byte for byte" \
  cmp -s <(sed -n '1,/^## Execution status/p' "$plan" | sed '$d') <(printf '%s\n\n' "$original")
check "execution-status write: the new section holds the whole ledger" \
  contains "$(cat "$plan")" "Gate do-it: waiting for owner"

printf '# Middle\n\n## Execution status\n\nold\n\n## Later\n\nkept\n' >"$repo/docs/plans/2026-01-01-middle.md"
middle_workspace=$(cd "$repo" && bash "$delegate/workspace" "$repo/docs/plans/2026-01-01-middle.md")
printf '# build ledger: plan middle\n' >"$middle_workspace/progress.md"
status write "$repo/docs/plans/2026-01-01-middle.md" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a section followed by another is replaced in place" \
  equals "$(sed -n '/^old$/p;/^## Later$/,$p' "$repo/docs/plans/2026-01-01-middle.md")" $'## Later\n\nkept'

rm "$ledger"
status restore "$plan"
check "execution-status restore: recreates a missing ledger from the copy" \
  equals "$code|$out|$err|$(cat "$ledger")" "0|$ledger|execution-status: recreated the ledger from the plan's Execution status|# build ledger: plan $plan
Task 1 pre-gate: complete (no commits)
Gate do-it: waiting for owner"
status restore "$plan"
check "execution-status restore: a matching ledger stays" \
  equals "$code|$err" "0|execution-status: the ledger matches the plan's Execution status"
printf 'Pause 2026-01-01T10:00:00+0000: resume at Task 1 pre-gate\n' >>"$ledger"
status restore "$plan"
check "execution-status restore: keeps a ledger that extends the copy" \
  equals "$code|$err|$(tail -n 1 "$ledger")" "0|execution-status: kept the ledger, which extends the plan's copy|Pause 2026-01-01T10:00:00+0000: resume at Task 1 pre-gate"
head -n 2 "$ledger" >"$ledger.short" && mv "$ledger.short" "$ledger"
status restore "$plan"
check "execution-status restore: replaces a ledger that the copy extends" \
  equals "$code|$err|$(tail -n 1 "$ledger")" "0|execution-status: replaced the ledger with the plan's longer copy|Gate do-it: waiting for owner"
printf '# build ledger: plan %s\nTask 1: complete (commits a..b, review clean)\n' "$plan" >"$ledger"
status restore "$plan"
check "execution-status restore: a ledger and a copy that disagree exit 1" \
  equals "$code|$(grep -c 'disagree' <<<"$err")" "1|1"
printf '# No fence\n\n## Execution status\n\nold\n' >"$repo/docs/plans/2026-01-01-no-fence.md"
status restore "$repo/docs/plans/2026-01-01-no-fence.md"
check "execution-status restore: a section without a fenced ledger exits 1" \
  equals "$code|$err" "1|execution-status: the Execution status in $repo/docs/plans/2026-01-01-no-fence.md has no fenced ledger"
printf '# Plain\n' >"$repo/docs/plans/2026-01-01-plain.md"
status restore "$repo/docs/plans/2026-01-01-plain.md"
check "execution-status restore: a plan without the section changes nothing" \
  equals "$code|$err" "0|execution-status: $repo/docs/plans/2026-01-01-plain.md has no Execution status; nothing to restore"

cat >"$ledger" <<'EOF'
# build ledger: plan docs/plans/2026-01-01-paused.md
Ruling: keep a\b & "quoted" $HOME 'x' %s `tick`; costs nothing
EOF
cp "$ledger" "$tmp/special-ledger"
status write "$plan" "Task 1 pre-gate (gate do-it)"
rm "$ledger"
status restore "$plan"
check "execution-status: a ledger line with shell, sed and awk specials survives write and restore byte for byte" \
  cmp -s "$ledger" "$tmp/special-ledger"

printf '# No newline\n\nlast' >"$repo/docs/plans/2026-01-01-no-newline.md"
no_newline_workspace=$(cd "$repo" && bash "$delegate/workspace" "$repo/docs/plans/2026-01-01-no-newline.md")
printf '# build ledger: plan no-newline\n' >"$no_newline_workspace/progress.md"
status write "$repo/docs/plans/2026-01-01-no-newline.md" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a plan without a final newline gets the section after a blank line" \
  equals "$code|$(sed -n '3,5p' "$repo/docs/plans/2026-01-01-no-newline.md")" $'0|last\n\n## Execution status'

# --- task-start --------------------------------------------------------------

execute=$build/skills/execute/scripts
repo=$(new_repo task-start)
plan=$repo/docs/plans/2026-01-01-fixture.md
fixture >"$plan"
start() {
  run bash -c 'cd "$1" && shift && bash "$@"' _ "$repo" "$execute/task-start" "$@"
}

start "$plan" 2 --part pre-gate
check "task-start: passes --part to task-brief" \
  equals "$code|$(sed -n 's/^brief: .*\///p' <<<"$out")" "0|task-2-pre-gate-brief.md"
check "task-start: prints BASE" \
  equals "$(sed -n 's/^base: //p' <<<"$out")" "$(git -C "$repo" rev-parse HEAD)"
start "$plan" 2
check "task-start: a gated task without --part fails as task-brief does" \
  equals "$code" "3"
start "$plan" 2 --bogus pre-gate
check "task-start: anything but --part as the third argument is a usage error" \
  equals "$code" "2"

# --- Summary -----------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
  echo "build scripts: $failures failure(s)"
  exit 1
fi
echo "build scripts: all passed"
