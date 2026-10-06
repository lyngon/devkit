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
edited=c8a31cb076b21999bd2cdcfa5f446a7a6644de88037087112fa18bd90cc13984
run bash "$delegate/pin" --check "sha256:$hello" "$repo/edited.txt"
check "pin --check: an edited file exits 1 and names both hashes, the found one the edited file's" \
  equals "$code|$err" "1|pin: $repo/edited.txt does not match its pin: pinned sha256:$hello, found sha256:$edited"
run bash "$delegate/pin" --check "sha256:abc" "$repo/artifact.txt"
check "pin --check: a malformed pin is a usage error that names it" \
  equals "$code|$err" "2|pin: not a pin: sha256:abc"
run bash "$delegate/pin" "$repo/missing.txt"
check "pin: a missing file is an error that names it, with nothing printed" \
  equals "$code|$out|$err" "2||pin: no such file: $repo/missing.txt"
run bash "$delegate/pin" "$repo/artifact.txt" "$repo/missing.txt"
check "pin: a missing file after a valid one prints nothing for the valid one" \
  equals "$code|$out|$err" "2||pin: no such file: $repo/missing.txt"
mkdir -p "$repo/a-directory"
run bash "$delegate/pin" "$repo/artifact.txt" "$repo/a-directory"
check "pin: a directory is refused by name, with nothing printed" \
  equals "$code|$out|$err" "2||pin: not a readable file: $repo/a-directory"
# Root reads a file without read permission, so only others can test it.
if [ "$(id -u)" -ne 0 ]; then
  printf 'hidden\n' >"$repo/unreadable.txt"
  chmod 000 "$repo/unreadable.txt"
  run bash "$delegate/pin" "$repo/unreadable.txt"
  check "pin: a file without read permission is refused by name, with nothing printed" \
    equals "$code|$out|$err" "2||pin: not a readable file: $repo/unreadable.txt"
  chmod 600 "$repo/unreadable.txt"
fi
blank=$tmp/blank-hash-tool
mkdir -p "$blank"
ln -s "$(command -v bash)" "$blank/bash"
printf '#!%s\nexit 0\n' "$(command -v bash)" >"$blank/sha256sum"
chmod +x "$blank/sha256sum"
run env -i PATH="$blank" "$blank/bash" "$delegate/pin" "$repo/artifact.txt"
check "pin: an empty hash is refused by name, with nothing printed" \
  equals "$code|$out|$err" "2||pin: could not hash $repo/artifact.txt"
run env -i PATH="$blank" "$blank/bash" "$delegate/pin" --check "sha256:$hello" "$repo/artifact.txt"
check "pin --check: an empty hash is refused by name, not reported as a mismatch" \
  equals "$code|$out|$err" "2||pin: could not hash $repo/artifact.txt"
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

fixture | sed 's/Owner gate \(.apply-thing.\)/Owner Gate \1/' >"$plan"
brief "$plan" 2
check "task-brief refuses a Title Case gate marker rather than extracting the task ungated" \
  equals "$code|$err" "3|task-brief: task 2: malformed owner gate marker: - [ ] **Step 2: Owner Gate \`apply-thing\`**"

fixture | sed 's/^\(| .apply-thing. | \)2 |/\11 |/' >"$plan"
brief "$plan" 1
check "task-brief refuses a task the index gates when the task has no marker for it" \
  equals "$code|$err" "3|task-brief: owner gate \`apply-thing\` is indexed for task 1, which has no marker for it"

fixture | sed 's/^\(| .apply-thing. | \)2 |/\1Task 1 |/' >"$plan"
brief "$plan" 1
check "task-brief reads an index Task cell of \"Task 1\" as task 1, and refuses the task without its marker" \
  equals "$code|$err" "3|task-brief: owner gate \`apply-thing\` is indexed for task 1, which has no marker for it"

fixture | sed 's/^- \[ \] \*\*Step 2: Commit\*\*$/- [ ] **Step 2: Owner gateway setup**/' >"$plan"
brief "$plan" 1
check "task-brief: a step titled with \"Owner gateway\" is no gate marker, and the task extracts ungated" \
  equals "$code|$(grep -c '^- \[ \] \*\*Step 2: Owner gateway setup\*\*$' <<<"$body")" "0|1"
fixture >"$plan"

brief "$plan" 7
check "task-brief: a missing task exits 3" \
  equals "$code|$err" "3|task-brief: task 7 not found (no heading matching Task 7)"

# A task with no step line, holding a heading and a fence inside a fenced
# block, between a task and a trailing Execution status.
stepless_fixture() {
  cat <<'EOF'
# Stepless

## Plan

### Global Constraints

- Constraint one.

### Task 1 `first`: Before

Before text.

### Task 2 `dictated`: No steps

**Intent:** Place the text.

````markdown
## Inside heading

```bash
echo hi
```
````

After the block.

**Commit:** `docs: place the text`

### Task 3 `after`: After

After text.

## Execution status

Resume at: Task 3
EOF
}

stepless=$repo/docs/plans/2026-01-01-stepless.md
stepless_fixture >"$stepless"
brief "$stepless" 2
stepless_task=$(sed -n '/^### Task 2 /,/^\*\*Commit:\*\*/p' "$stepless")
check "task-brief: a task with no step line exits 0 and its brief holds every line of the task" \
  equals "$code|$(head -n "$(wc -l <<<"$stepless_task")" <<<"$body")" "0|$stepless_task"
check "task-brief: a heading and a three-backtick fence inside a four-backtick block are intact" \
  equals "$(sed -n $'/^````markdown$/,/^\*\*Commit:\*\*/p' <<<"$body")" $'````markdown\n## Inside heading\n\n```bash\necho hi\n```\n````\n\nAfter the block.\n\n**Commit:** `docs: place the text`'
check "task-brief: a task with no step line holds nothing of the next task or the Execution status" \
  equals "$(grep -c -e 'Task 3' -e 'After text' -e 'Resume at' -e 'Execution status' <<<"$body" || true)" "0"
check "task-brief: a task with no step line ends with the Global Constraints" \
  equals "$(tail -n 3 <<<"$body")" $'### Global Constraints\n\n- Constraint one.'

# A plan whose task 3 heading and gate steps carry slugs.
slug_fixture() {
  cat <<EOF
# Slugs

## Plan

### Owner Gates

| ID | Task | Performed by | Consequences | Pre-approved |
| --- | --- | --- | --- | --- |
| \`apply-thing\` | 4 | agent | creates the thing | no |

### Global Constraints

- Constraint one.

### Task 1: One

- [ ] **Step 1: Do it**

### Task 12: Twelve

- [ ] **Step 1: Do it**

$1

- [ ] **Step 1: Do it**

### Task 4 \`gated\`: Gated

- [ ] **Step 1 \`save-plan\`: Save the plan**

- [ ] **Step 2: Owner gate \`apply-thing\`**
  - Show: \`thing.plan\`
  - Ask: "Apply thing.plan?"
  - Performed by: agent, \`apply thing.plan\`
  - Consequences: creates the thing; it cannot be removed
  - On no: record the reason and stop

- [ ] **Step 3 \`apply\`: Apply**

${2:-}
EOF
}

slugged=$repo/docs/plans/2026-01-01-slugged.md
slug_fixture $'### Task 3 `rate-limiter`: Title' >"$slugged"
brief "$slugged" 3 --label
check "task-brief: --label prints the number and the slug and writes no brief" \
  equals "$code|$out|$(compgen -G "$repo/tmp/build/2026-01-01-slugged/task-3*" || true)" "0|Task 3 rate-limiter|"
unslugged=$repo/docs/plans/2026-01-01-unslugged.md
slug_fixture '### Task 3: Title' >"$unslugged"
brief "$unslugged" 3 --label
check "task-brief: --label prints the number alone for a heading without a slug" \
  equals "$code|$out" "0|Task 3"
brief "$slugged" 4 --label
check "task-brief: --label works for a task with an owner gate without --part" \
  equals "$code|$out" "0|Task 4 gated"
brief "$slugged" 9 --label
check "task-brief: --label exits 3 for a task the plan does not have" \
  equals "$code|$out" "3|"
brief "$slugged" 3 --label --part pre-gate
check "task-brief: --label together with --part is a usage error" \
  equals "$code|$out" "2|"
brief "$slugged" 3 --part pre-gate --label
check "task-brief: --part followed by --label is a usage error and writes no file" \
  equals "$code|$out|$(compgen -G "$repo/tmp/build/2026-01-01-slugged/*--label*" || true)" "2||"
brief "$slugged" 3 --label "$tmp/label-out.md"
check "task-brief: --label together with an OUTFILE is a usage error" \
  equals "$code|$out|$(compgen -G "$tmp/label-out.md*" || true)" "2||"
brief "$slugged" 1 --label
check "task-brief: asking for Task 1 never returns Task 12" \
  equals "$code|$out" "0|Task 1"
brief "$slugged" 1
check "task-brief: the brief of Task 1 holds no line of Task 12" \
  equals "$code|$(grep -c 'Task 12' <<<"$body")" "0|0"

brief "$slugged" 3
check "task-brief: the brief of a task with a slug is task-3-rate-limiter-brief.md" \
  equals "$code|${out##*/}" "0|task-3-rate-limiter-brief.md"
brief "$slugged" 4 --part pre-gate
check "task-brief: the pre-gate brief of a task with a slug is task-4-gated-pre-gate-brief.md" \
  equals "$code|${out##*/}" "0|task-4-gated-pre-gate-brief.md"
check "task-brief: the pre-gate brief ends at the gate block when the other steps carry a slug" \
  equals "$(grep -c -e $'Step 1 `save-plan`' -e $'Owner gate `apply-thing`' -e $'Step 3 `apply`' -e '^Stop here' <<<"$body")|$(grep -c $'Step 3 `apply`' <<<"$body")" "3|0"
brief "$slugged" 4 --part post-gate
check "task-brief: the post-gate brief of a task with a slug is task-4-gated-post-gate-brief.md" \
  equals "$code|${out##*/}" "0|task-4-gated-post-gate-brief.md"
check "task-brief: the post-gate brief starts at the gate block when the other steps carry a slug" \
  equals "$(grep -c $'Step 1 `save-plan`' <<<"$body")|$(grep -c $'Owner gate `apply-thing`' <<<"$body")|$(grep -c $'Step 3 `apply`' <<<"$body")" "0|1|1"
brief "$unslugged" 3
check "task-brief: a task without a slug keeps task-3-brief.md" \
  equals "$code|${out##*/}" "0|task-3-brief.md"

refused_slug() {
  local label=$1 heading=$2 extra=$3 slug=$4
  slug_fixture "$heading" "$extra" >"$repo/docs/plans/2026-01-01-refused.md"
  rm -rf "$repo/tmp/build/2026-01-01-refused"
  brief "$repo/docs/plans/2026-01-01-refused.md" 3
  check "task-brief refuses $label" \
    equals "$code|$(grep -c -F -- "$slug" <<<"$err")|$(compgen -G "$repo/tmp/build/2026-01-01-refused/task-3*" || true)" "3|1|"
  rm -f "$tmp/refused-out.md"
  brief "$repo/docs/plans/2026-01-01-refused.md" 3 "$tmp/refused-out.md"
  check "task-brief refuses $label with an OUTFILE and writes nothing" \
    equals "$code|$(compgen -G "$tmp/refused-out.md*" || true)" "3|"
}
refused_slug "a slug with an uppercase letter" $'### Task 3 `Rate-Limiter`: Title' "" "Rate-Limiter"
refused_slug "a slug with an underscore" $'### Task 3 `rate_limiter`: Title' "" "rate_limiter"
refused_slug "a slug with a doubled hyphen" $'### Task 3 `rate--limiter`: Title' "" "rate--limiter"
refused_slug "a slug with a trailing hyphen" $'### Task 3 `rate-`: Title' "" "rate-"
refused_slug "the slug pre-gate" $'### Task 3 `pre-gate`: Title' "" "pre-gate"
refused_slug "the slug post-gate" $'### Task 3 `post-gate`: Title' "" "post-gate"
refused_slug "a slug that two task headings share" $'### Task 3 `rate-limiter`: Title' $'### Task 5 `rate-limiter`: Other\n\n- [ ] **Step 1: Do it**' "rate-limiter"
fenced_duplicate=$'~~~markdown\n### Task 5 `rate-limiter`: In a fence\n~~~'
slug_fixture $'### Task 3 `rate-limiter`: Title' "$fenced_duplicate" >"$repo/docs/plans/2026-01-01-fenced.md"
brief "$repo/docs/plans/2026-01-01-fenced.md" 3
check "task-brief: a heading inside a fence does not count as sharing a slug" \
  equals "$code|${out##*/}" "0|task-3-rate-limiter-brief.md"

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
check "execution-status write: a section followed by another is replaced in place, the lines before it and the blank line before the next heading kept" \
  equals "$(cat "$repo/docs/plans/2026-01-01-middle.md")" "$(cat <<'EOF'
# Middle

## Execution status

The run paused here; `build:finish` removes this section with the rest of the plan.
The fence holds the ledger verbatim, and an executor recreates `progress.md` from it when its workspace has none.

Resume at: Task 1 pre-gate (gate do-it)

````text
# build ledger: plan middle
````

## Later

kept
EOF
)"

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

# own_plan <slug> <first line>: a plan with that one line and its own
# workspace, printing the plan's path; its ledger is ledger_of_plan.
own_plan() {
  local p=$repo/docs/plans/2026-01-01-$1.md
  printf '%s\n' "$2" >"$p"
  echo "$p"
}
ledger_of_plan() {
  echo "$(cd "$repo" && bash "$delegate/workspace" "$1")/progress.md"
}

p=$(own_plan ledger-newline '# Ledger newline')
printf '# build ledger: plan ledger-newline\nGate do-it: waiting for owner' >"$(ledger_of_plan "$p")"
status write "$p" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a ledger without a final newline keeps the closing fence on its own line" \
  equals "$code|$(tail -n 2 "$p")" $'0|Gate do-it: waiting for owner\n````'
status restore "$p"
check "execution-status write: a ledger without a final newline gets one, so it matches its copy" \
  equals "$code|$err" "0|execution-status: the ledger matches the plan's Execution status"

p=$(own_plan guard '# Guard')
printf '# build ledger: plan guard\n````\n' >"$(ledger_of_plan "$p")"
status write "$p" "Task 1 pre-gate (gate do-it)"
check "execution-status write: refuses a ledger line of four backticks and leaves the plan" \
  equals "$code|$err|$(cat "$p")" "2|execution-status: the ledger holds a line starting with four backticks after any indentation, which would end the fence|# Guard"
printf '# build ledger: plan guard\n   ````\n' >"$(ledger_of_plan "$p")"
status write "$p" "Task 1 pre-gate (gate do-it)"
check "execution-status write: refuses a ledger line of four backticks indented by three spaces" \
  equals "$code|$err|$(cat "$p")" "2|execution-status: the ledger holds a line starting with four backticks after any indentation, which would end the fence|# Guard"

p=$(own_plan resume-newline '# Resume newline')
printf '# build ledger: plan resume-newline\n' >"$(ledger_of_plan "$p")"
status write "$p" $'Task 1 pre-gate (gate do-it)\nResume at: Task 9'
check "execution-status write: a RESUME_AT holding a newline is a usage error that leaves the plan" \
  equals "$code|$err|$(cat "$p")" "2|execution-status: RESUME_AT holds a newline; it must be one line|# Resume newline"

p=$repo/docs/plans/2026-01-01-fenced.md
printf '# Fenced\n\n~~~markdown\n## Execution status\n\nan example\n~~~\n' >"$p"
fenced_original=$(cat "$p")
status restore "$p"
check "execution-status restore: a fenced Execution status heading is not the section" \
  equals "$code|$err" "0|execution-status: $p has no Execution status; nothing to restore"
printf '# build ledger: plan fenced\n' >"$(ledger_of_plan "$p")"
status write "$p" "Task 1 pre-gate (gate do-it)"
check "execution-status write: a fenced Execution status heading stays, and the section is appended after it" \
  equals "$code|$(sed -n '1,7p' "$p")|$(grep -c '^## Execution status$' "$p")|$(sed -n '9p' "$p")" "0|$fenced_original|2|## Execution status"

p=$(own_plan no-ledger '# No ledger')
status write "$p" "Task 1 pre-gate (gate do-it)"
check "execution-status write: without a ledger, exits 2 and leaves the plan" \
  equals "$code|$err|$(cat "$p")" "2|execution-status: no ledger at $(ledger_of_plan "$p")|# No ledger"

usage_msg="usage: execution-status write PLAN_FILE RESUME_AT | execution-status restore PLAN_FILE"
status
check "execution-status: no arguments is a usage error" \
  equals "$code|$err" "2|$usage_msg"
status write "$p"
check "execution-status: write without RESUME_AT is a usage error" \
  equals "$code|$err" "2|$usage_msg"
status restore "$p" extra
check "execution-status: restore with an extra argument is a usage error" \
  equals "$code|$err" "2|$usage_msg"
status bogus "$p"
check "execution-status: an unknown command is a usage error" \
  equals "$code|$err" "2|$usage_msg"
status restore "$repo/docs/plans/nowhere.md"
check "execution-status: a missing plan file exits 2" \
  equals "$code|$err" "2|no such plan file: $repo/docs/plans/nowhere.md"

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
start "$plan" 2 --part
check "task-start: --part without a value is a usage error" \
  equals "$code|$err" "2|usage: task-start PLAN_FILE TASK_NUMBER [--part pre-gate|post-gate]"

start_slugged=$repo/docs/plans/2026-01-01-slugged.md
slug_fixture $'### Task 3 `rate-limiter`: Title' >"$start_slugged"
start "$start_slugged" 3
check "task-start: prints brief, base and label, in that order" \
  equals "$code|$(cut -d: -f1 <<<"$out" | paste -sd, -)" "0|brief,base,label"
check "task-start: the label of a task with a slug is its number and slug" \
  equals "$(sed -n 's/^label: //p' <<<"$out")" "Task 3 rate-limiter"
start "$start_slugged" 4 --part pre-gate
check "task-start: the label is the same with --part" \
  equals "$code|$(sed -n 's/^label: //p' <<<"$out")" "0|Task 4 gated"
start_unslugged=$repo/docs/plans/2026-01-01-unslugged.md
slug_fixture '### Task 3: Title' >"$start_unslugged"
start "$start_unslugged" 3
check "task-start: the label of a task without a slug is its number" \
  equals "$(sed -n 's/^label: //p' <<<"$out")" "Task 3"

# --- task-done ---------------------------------------------------------------

repo=$(new_repo task-done)
plan=$repo/docs/plans/2026-01-01-fixture.md
fixture >"$plan"
git -C "$repo" add -A
git -C "$repo" commit -q -m "docs(plan): fixture"
base=$(git -C "$repo" rev-parse HEAD)
done_run() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$repo" "$build/skills/execute/scripts/task-done" "$@"
}
ledger_of() {
  cat "$(cd "$repo" && "$delegate/workspace" "$plan")/progress.md"
}

done_run "$plan" 1 "$base" -- true
check "task-done: a passing check that prints nothing exits 0" \
  equals "$code" "0"
check "task-done: a passing check that prints nothing is recorded as (no output)" \
  contains "$(ledger_of)" "tests: true → (no output))"
done_run "$plan" 2 "$base" -- bash -c 'echo ok; echo'
check "task-done: a check with output is recorded" \
  contains "$(ledger_of)" "Task 2: complete (commits"
check "task-done: a blank line after the output does not replace it" \
  contains "$(ledger_of)" "→ ok)"
done_run "$plan" 3 "$base" -- bash -c "printf '3/3 pass\n\r   \r\n'"
check "task-done: a line of only a carriage return and spaces does not replace the output" \
  contains "$(ledger_of)" "→ 3/3 pass)"
check "task-done: a task without a slug keeps its ledger line and log name" \
  equals "$(grep -c '^Task 3: complete (commits' <<<"$(ledger_of)")|$(compgen -G "$(cd "$repo" && "$delegate/workspace" "$plan")/task-3-tests.log" | wc -l)" "1|1"

done_slugged=$repo/docs/plans/2026-01-01-slugged.md
slug_fixture $'### Task 3 `rate-limiter`: Title' >"$done_slugged"
slugged_ledger() {
  cat "$(cd "$repo" && "$delegate/workspace" "$done_slugged")/progress.md"
}
done_run "$done_slugged" 3 "$base" -- bash -c 'echo ok'
check "task-done: a task with a slug is recorded under its label" \
  equals "$code|$(sed -n 's/^\(Task 3 rate-limiter: complete (commits\).*/\1/p' <<<"$(slugged_ledger)")" "0|Task 3 rate-limiter: complete (commits"
check "task-done: a task with a slug keeps its test output in task-3-rate-limiter-tests.log" \
  equals "$(cat "$(cd "$repo" && "$delegate/workspace" "$done_slugged")/task-3-rate-limiter-tests.log")" "ok"

done_run "$done_slugged" 3 "$base" -- bash -c 'echo broken; exit 4'
check "task-done: a failing check exits with its status and names the task by its label" \
  equals "$code|${err%% (full output*}" "4|task-done: test command exited 4; Task 3 rate-limiter NOT recorded"
check "task-done: a failing check records nothing" \
  equals "$(grep -c 'broken' <<<"$(slugged_ledger)" || true)|$(grep -c '^Task 3 rate-limiter: complete' <<<"$(slugged_ledger)")" "0|1"

# A refused task stops task-done before the check runs.
refused_done() {
  local label=$1 heading=$2 n=$3 plan_path=$repo/docs/plans/2026-01-01-refused-done.md
  slug_fixture "$heading" >"$plan_path"
  rm -rf "$repo/tmp/build/2026-01-01-refused-done" "$tmp/ran"
  done_run "$plan_path" "$n" "$base" -- touch "$tmp/ran"
  check "task-done: $label exits non-zero, runs no check and records nothing" \
    equals "$([ "$code" -ne 0 ] && echo nonzero)|$(compgen -G "$tmp/ran" || true)|$(compgen -G "$repo/tmp/build/2026-01-01-refused-done/*" || true)" "nonzero||"
}
refused_done "a malformed slug" $'### Task 3 `Rate_Limiter`: Title' 3
refused_done "a task the plan does not have" $'### Task 3 `rate-limiter`: Title' 9

# --- Summary -----------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
  echo "build scripts: $failures failure(s)"
  exit 1
fi
echo "build scripts: all passed"
