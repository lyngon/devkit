# Review on the pull request

## Design

### Goal

The user reviews work on its pull request, not before each commit.
In this repository and in every repository that uses the devkit plugins, the agent commits on a feature branch without asking, one concern per commit.
Once the work is done and the full check passes, it pushes the branch and opens a pull request without asking.
Merging stays the user's decision.
For that rule to reach the agent at all, the convention skills must be invoked, which today none of them are.

ADR 0016 already dropped per-commit review for planned work.
Interactive work kept the older habit: stage, run the full check, stop for file review, commit when told.
That habit keeps the user in series with every commit, and it produces worse history.
In pull request 2, holding every commit for review left twelve concerns mixed in one working tree, and they had to be rebuilt into commits afterwards.

### Approach

The standing authorization lives in the `conventions:engineering` skill and nowhere else.
The text says it counts as the user asking.
That is what overrides the agent's default of committing and pushing only on request.

A rule in a skill body only works if the body reaches the agent, and today no convention body does.
A `paths` skill is listed with its description, but its body loads only when the agent invokes the skill.
Every `conventions` description says "loaded automatically", which tells the agent it need not invoke anything.
So this design also makes the conventions reach the agent, in a way that works for all of them, not only for this rule:

- Every `conventions` description ends with when to invoke it ("Invoke before any engineering work", "Invoke before writing or editing any Markdown file").
- A general `SessionStart` hook in `conventions` says that no skill loads on its own, the conventions included, and that the agent invokes `conventions:engineering` before any engineering work and the conventions skill for a file's kind before editing it.
  It carries the generic flow lines that the `repo` hook holds today, which settles the item deferred on 2026-09-23; `repo` keeps only the structure line.

Headless `claude -p` sessions on 2026-09-29 in a scratch repository with one commit on `main` were asked to add a sentence to `README.md`, with `conventions` and `writing` loaded from their directories:

| Variant | Skills invoked | Committed on a branch |
| --- | --- | --- |
| The new rule in the body only | none | no |
| The new rule, reworded descriptions | `engineering`, `markdown` | yes |
| The new rule, reworded descriptions, general hook | `engineering`, `markdown`, `documents` | yes |

Each variant ran once, so the plan repeats the check before relying on it.
A session that commits without having invoked the skill falls back to the default and asks, which is the safe direction to fail in.

Everything else points to that rule or carries out its procedure:

- `shared/WORKFLOW.md` shows commit, push and pull request as steps of each flow.
- `build:finish` is the one procedure that ends a branch: full check, plan removal, push, pull request, description.
- `init`, `add-package` and `add-skill` commit their own output instead of saying "Do not commit".
- ADR 0016 is edited in place.
  The user accepted this as an exception while the devkit is young; the ADR rule does not change.

Facts behind the choice, checked on 2026-09-29:

- Auto mode allows pull request creation and pushes to any branch, the default branch included.
  The limits below hold only because the instructions say so.
- A plugin cannot ship permission or `autoMode` settings; only `agent` and `subagentStatusLine` take effect.
- The `repo` session hook reaches only repositories that install `repo`, and it says "Conventions load on their own by file path", which is false.
- The eval harness refuses any eval that grants Bash on a machine whose `~/.aws` holds a symbolic link, as this one does until `nixos-configs` copies the file instead.

### Components

#### `plugins/conventions/skills/engineering/SKILL.md`

The "Handing over" section becomes this text, verbatim:

```md
## Committing and handing over

These are the user's standing instructions: they count as being asked to commit, push and open a pull request.

- Work on a feature branch named `<type>/<slug>`, after the Conventional Commits type of its main change. On the default branch, create one first.
- Commit without asking whenever a concern is done: one concern per commit, in Conventional Commits form. Commits not yet pushed may be amended or reordered.
- When the work is done and the full check passes, push the branch and open a pull request without asking. The user reviews the pull request and decides the merge.
- Run the full check before every push. Never disable, skip or weaken a check or hook to get past it.
- Never rewrite pushed history without asking; fixes after a push are new commits.
- Ask before any other effect outside the branch: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish.
- Without a remote, commit and report. With a remote but no forge CLI, push and hand over the pull request link the forge printed.
- Report faithfully: failing checks with their output, skipped steps by name, done things plainly.
```

#### `plugins/conventions/skills/*/SKILL.md` descriptions

Each description says what the skill covers and ends with when to invoke it; "Background knowledge, loaded automatically" goes.
`paths` and `user-invocable: false` stay.
`validate-marketplace` requires the "Invoke before" ending on every conventions skill, and `render-plugin-list.sh` labels these skills "agent-invoked" in the README table instead of "by path".

| Skill | Ends with |
| --- | --- |
| `engineering` | "Invoke before any engineering work, before the first edit of a session." It also names committing, pushing and pull requests among what it covers. |
| `markdown` | "Invoke before writing or editing any Markdown file." |
| `documents` | "Invoke before writing or editing one of them." |
| `adr` | "Invoke before writing or editing an ADR." |
| `python` | "Invoke before writing or editing a Python file, stub or notebook." |
| `typescript` | "Invoke before writing or editing a TypeScript or JavaScript file." |
| `nix` | "Invoke before writing or editing a Nix file or `devenv.yaml`." |
| `shell` | "Invoke before writing or editing a shell script or a file under a `scripts/` directory." |

#### `plugins/conventions/hooks/`

A new `SessionStart` hook: `hooks.json`, `session-start.sh` and `session-start.txt`, in the style of the `repo` hook it replaces.
The text, verbatim:

```text
This is a Lyngon repository. The devkit plugins provide skills; invoke them instead of working from memory. No skill loads on its own, the conventions skills included: a skill's text reaches you only when you invoke it.
- conventions:engineering before any engineering work, and the conventions skill for a file's kind before editing that file.
- /discover:brainstorm to toss ideas around without writing anything.
- /discover:approach before building anything that has more than one reasonable design; it classifies the work and gates implementation on approval.
- /build:plan once a design is approved, then /build:delegate (or /build:execute) to build it and /build:finish to push the branch and open the pull request.
- practice:tdd, practice:debug, practice:verify and review:receive whenever their description matches; process skills come before implementation.
- /writing:unslop before handing over prose.
The flow between these skills, and where the user decides, is WORKFLOW.md next to the approach and plan skills.
Terms are in CONCEPTS.md, decisions in docs/adr/, working rules in CLAUDE.md.
```

`plugins/conventions/README.md` stops saying that a skill loads on its own and is never invoked by name; it describes the descriptions and the hook instead.

#### `docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`

Edited in place; the file name and title stay.

- The decision paragraph names the pull request as the second gate.
  The agent pushes and opens it without asking, and merging is the user's.
  This holds for all work; without a plan, the pull request is the only gate.
- The first Consequences bullet, "Interactive sessions without a plan keep the earlier habit", is replaced.
  Interactive work commits per concern on a feature branch and ends in a pull request.
  The standing rule lives in `conventions:engineering`, because only a plugin reaches every repository.
- A new considered option: keep file review before commit in interactive sessions.
  Rejected because it keeps the user in series with every commit and mixes concerns in one working tree (pull request 2).

#### `shared/WORKFLOW.md`

Symlinked into `build:plan` and `discover:approach`.

- The table: a small change with an obvious design also ends with `/build:finish`, and the finished-branch row says that `/build:finish` pushes and opens the pull request.
- Bounded change: step 4 runs `/review:request` before the pull request.
  Step 5, `/build:finish`, runs the full check, pushes the branch and opens the pull request.
  A new gate step follows: the user reviews the pull request and merges it or asks for changes.
  Feedback goes through `review:receive`; fixes are new commits, pushed after the full check.
- Architectural change: step 5 pushes and opens the pull request instead of presenting a menu.
  At gate 2 the user reviews the pull request, starting from the rulings and deferred minors in its description, and merges it or asks for changes.
- "Who decides what": the user decides whether the pull request merges.
  The side-effect stop takes the ask-first list of the engineering text: "a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish".
  Pushing the feature branch and opening its pull request are not stops.
  The closing sentence says that no flow has a per-commit or per-file human review, and names `conventions:engineering` as the home of the rule.

#### `plugins/build/skills/finish/SKILL.md`

Vendored, so every change gets a line under "Local patches" in its `UPSTREAM.md`.

- The menu goes.
  After the full check and the plan removal, finish pushes the branch and opens the pull request without asking.
  It merges locally or keeps the branch only when the user asked for that.
  From a detached HEAD, it pushes a new branch and opens the pull request.
  Without a remote, it reports and keeps the branch.
  With a remote but no forge CLI, it pushes and hands over the creation link the forge printed.
- The base of a pull request is the fork point, or else the remote's default branch, with no question asked.
  A wrong base takes one step to fix on the forge.
  The confirmation stays for a local merge.
- The description, in this order:
  1. What changed and why, in a short paragraph.
  2. "Decisions for you": anything the user must decide, or "none".
  3. For planned work, "Rulings I made" and "Deferred minors", and a link to the plan file at the last commit that still had it. The plan is removed before the push, so the net diff of the pull request does not show it.
  4. Review findings nobody fixed.
  5. Verification: the full check command and its result, and any other evidence by name.
- The worktree and the plan workspace stay until the work lands, and the report ends with the landing steps, as option 2 does today.
- Changes asked for on the pull request are made in the worktree as new commits and pushed after the full check.
  The description is updated when its lists change.
- The frontmatter description, the overview, the quick reference and the rationalization table follow.
  "They obviously want it merged" now says to open the pull request and merge only when asked.
  New rows cover asking before the push and amending a commit that was already pushed.
- `UPSTREAM.md` also gets a dated line in its review notes: pushing and opening a pull request no longer wait for a choice, while merging, force-pushing and discarding still do.
  Its "Why it is here" stops saying that the user chooses between merge, pull request and keep.

#### `plugins/build/skills/plan/SKILL.md`, `execute/SKILL.md`, `delegate/SKILL.md`

Vendored.

- The second gate is the pull request.
- The executors' stop list uses the reworded side-effect stop.
- The final message's two lists open the pull request description.
- The whole-branch review triages which findings must be fixed before the pull request, where it said "before merge".
- `plugins/build/README.md` says the same.

#### `plugins/discover/skills/approach/SKILL.md`

Vendored.
The bounded path runs `review:request` before the pull request and `build:finish` to push the branch and open it.

#### `plugins/review/skills/request/SKILL.md`

Vendored.

- The description and the mandatory list say "before opening a pull request" where they said "before merging".
- Minor findings that nobody fixed go into the pull request description.
- `plugins/review/README.md` follows.

#### `plugins/repo/skills/init/SKILL.md`

- Fresh mode ends with one root commit, `chore: initialize repository`, on `main`, packages included.
  If git gave the unborn branch another name, init renames it first.
  It asks before pushing, because the commit is on the default branch.
  Without a remote, the hand-off lists adding one and pushing.
- Adopt mode creates `chore/adopt-lyngon-conventions` before writing anything, when it starts on the default branch.
  It commits by concern: the documents, the baseline, CI, the structure, one commit per package.
  The commits are ordered so that each passes the hooks; two concerns share a commit when neither passes alone.
  It then finishes the branch with `/build:finish` when the build plugin is installed, and otherwise pushes and opens the pull request as the engineering convention says.
- When `init` calls `add-package`, `init` does the committing.

#### `plugins/repo/skills/add-package/SKILL.md`

Step 7 commits the package as one commit, `feat(<name>): add <kind> <name>`, on the current feature branch, creating one first when it is on the default branch.
It never pushes.
A call from `init` is the exception: `init` commits the package itself.

#### `plugins/repo/hooks/`

The generic lines move to the `conventions` hook, so `session-start.txt` goes.
`session-start.sh` prints only the structure line, and only when the root `CLAUDE.md` carries the structure marker; otherwise it prints nothing.
The `repo` README and any text that describes the hook follow.

#### `plugins/devkit/skills/add-skill/`

In `SKILL.md` (twice), `references/install.md` and `references/create.md`, "Do not commit" becomes: commit the result as one commit on the feature branch, with the message offered today, and never push.

#### Versions

Each commit that changes a plugin bumps that plugin's version by the commit's semver level and adds a `CHANGELOG.md` entry, so `conventions`, `build`, `discover` (for `WORKFLOW.md` and `approach`), `review`, `repo` and `devkit` all get at least one minor bump.
The plan fixes the numbers per commit.
The bundles do not change.

#### This repository's documents

- `CLAUDE.md`, the plugin-version convention: every commit with a user-visible change to a plugin bumps that plugin's version by the commit's own semver level and adds its own `CHANGELOG.md` entry, in the same commit.
- `CLAUDE.md`, the seed-prompt layout line: a seed prompt says how to start (the skill to invoke, or "a bounded change: no design file and no plan file"), names the branch, and ends with "Remove this file and its `docs/TODO.md` entry in the last commit".
  Commits, the check and the pull request are covered by the convention and not repeated.
- `README.md`: the "reviewed at two gates" bullet names the pull request, and the flow summary says `/build:finish` pushes the branch and opens the pull request.
  The line "Conventions load on their own by file path" says instead that agents invoke the conventions before working, as the `conventions` hook tells them.
- `docs/conventions/prerequisites.md`: "Skills that load without being asked, through `paths`" becomes skills whose description asks to be invoked for every matching file; the rule itself stays.
- `docs/seed-prompts/session-environment-hooks.md` loses "Do not commit until I have reviewed the files" and gains the removal line.
- `docs/TODO.md` gets a Deferred item: rethink the process for deferred items, possibly a skill that writes the TODO entry and, for a queued item, its seed prompt.
  The Deferred item of 2026-09-23 about moving the session hook's generic lines into a `core` plugin is removed, since this work does it.

### Data flow

1. A session starts, the `conventions` hook says to invoke `conventions:engineering` before any engineering work, and the agent invokes it, and the conventions for each kind of file it edits.
2. On the default branch, the agent creates a feature branch first.
3. It commits each concern as it finishes it.
4. When the work is done, bounded work gets a `review:request` and planned work the executor's whole-branch review; a small obvious change gets neither.
5. `build:finish` runs the full check, removes the plan, pushes, opens the pull request with its description, and reports the link and the landing steps.
6. The user reviews on the forge.
   Requested changes go through `review:receive` and come back as new commits, pushed after the full check.
7. The user merges, and the next session runs the landing steps.

### Error handling

- When the full check fails, nothing is pushed and the failures are reported with their output.
- When a hook fails on commit, the agent fixes the cause; never `--no-verify`.
- When a push is rejected because the remote branch moved, the agent integrates the remote commits, rebasing only commits not yet pushed, runs the full check and pushes again. It never force-pushes without asking.
- Without a remote, the agent commits and reports.
- Without a forge CLI, or with one that is not authenticated, it pushes and hands over the forge's creation link.
- When a pull request already exists for the branch, the push updates it, and the description is updated when its lists change.
- When the agent has not invoked the engineering skill by commit time, its default applies and it asks.

### Testing

- `devenv test`.
  It runs `validate-prerequisites` over the new engineering text and both hooks' text, `prose-lint`, markdownlint, shellcheck on the hook scripts, and `validate-marketplace` over the version bumps.
- A headless check, run by hand, since it costs tokens and needs a signed-in Claude Code.
  Each run starts a fresh scratch repository outside this one (so no `CLAUDE.md` of the devkit is picked up), with one commit on `main` and a `README.md`.
  It runs `claude -p` with `--setting-sources project`, so no user-level plugin loads, and reads the branch, the commits and the skills the session invoked.
  Two tasks: adding a sentence to `README.md`, and creating a small Python module.
  With `--plugin-dir plugins/conventions --plugin-dir plugins/writing`, three runs of each task must each invoke `conventions:engineering` (and `conventions:python` for the Python task) and leave one Conventional Commit on a new branch, with `main` unchanged.
  Without the plugins, the runs must leave the change uncommitted on `main`.
  Before the change, the with-plugin runs must fail too; that shows the check tests the change.
  The output goes into the pull request.
- No eval: the harness resolves a plugin's dependencies only from installed marketplaces, so `conventions`, which depends on `writing`, does not load in an eval run from its directory.
  The existing Python eval has therefore never loaded the conventions; that is flagged, not fixed, here.
- A check that the old habit is gone, shown both ways.
  Before the change, on 2026-09-29, it lists 32 lines; after the change it must list none:

  ```sh
  git grep -n -E 'Do not commit|do not stage|integration menu|Which option\?|until I have reviewed|commit when told|the finished branch|presents the options|before merg' -- plugins shared docs/adr README.md CLAUDE.md docs/seed-prompts ':!*CHANGELOG.md' ':!*UPSTREAM.md' ':!docs/seed-prompts/review-on-the-pull-request.md' ':!docs/seed-prompts/conclude-skill.md'
  ```

  Changelogs and provenance records are history.
  The seed prompt of this work quotes the old text, and `conclude-skill.md` is out of scope.
- No eval case for the commit behaviour: it needs Bash, which the harness refuses here, and the headless check covers it.

### Out of scope

- Owner gates for operational tasks (`docs/seed-prompts/owner-gates.md`), which lands second and reads the new text.
- The wrap-up skill and its seed prompt (`docs/seed-prompts/conclude-skill.md`), untouched.
- Merging without the user, auto-merge, CI changes, and managed `autoMode` settings.
- Changing the ADR rule to allow in-place edits.
- The `~/.aws` fix, which belongs in `nixos-configs`.
- The standard lines in the other queued seed prompts; `CLAUDE.md` already says seed prompts are removed when their work lands.

## Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `build:delegate` (recommended) or `build:execute` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The agent commits on a feature branch without asking and pushes and opens a pull request once the full check passes, and the conventions that say so reach the agent.

**Architecture:** The standing rule is a section of `conventions:engineering`.
Reworded descriptions and a `SessionStart` hook in `conventions` make agents invoke the convention skills, whose bodies otherwise never load.
`build:finish` becomes the procedure that pushes and opens the pull request; `WORKFLOW.md`, the executors, `review:request`, `init`, `add-package`, `add-skill`, ADR 0016 and this repository's documents follow.

**Tech stack:** Markdown skill files, Bash hook scripts, `jq`, the validators in `scripts/`, prek hooks through devenv, and headless `claude -p` sessions for the end-to-end check.

**Spec:** The `## Design` section of this file.

### Global Constraints

- Work on the branch `feat/review-on-the-pull-request`; never commit on `main`.
- Commit messages follow Conventional Commits (the `commitizen` hook checks them), one concern per commit, with no `Co-Authored-By` trailer and no mention of an agent.
- Every commit with a user-visible change to a plugin bumps that plugin's `version` in `.claude-plugin/plugin.json` and adds its own entry at the top of that plugin's `CHANGELOG.md`, headed `## <version> - 2026-09-29`, in the same commit. Each task names the versions.
- Markdown puts each sentence on its own line; no file or commit message contains an em dash, an en dash or a curly quote (the `prose-lint` hooks).
- Every change to a vendored skill (a skill directory with an `UPSTREAM.md`) gets a line under "Local patches" in that `UPSTREAM.md`, in the same commit.
- `shared/WORKFLOW.md` is edited in `shared/`, never through the symlinks in `plugins/build/skills/plan/` and `plugins/discover/skills/approach/`.
- `validate-prerequisites` scans plugin text: `review` declares only `git`, so its skill text names no document (`CLAUDE.md`, `CONCEPTS.md`, `docs/adr`); `conventions`, `build` and `discover` declare `documents`.
- Skill text stays agent-neutral: no Claude-specific wording unless the feature is Claude-only.
- Hook evidence is the output of an explicit run: `prek run --files <files>` per task, `devenv test` in Task 10. The devenv environment provides `prek`, `jq` and the validators; if one is missing, prefix the command with `devenv shell --`.
- The headless check runs its scratch repositories outside this repository, so no devkit `CLAUDE.md` or settings reach them.

### Review Focus

1. A resumed or compacted session must still carry the `conventions` hook text: `hooks.json` has no matcher, so the hook runs for every `SessionStart` source. Pinned in Task 1, Step 10.
2. Hook text with a double quote or a backslash must still produce valid JSON. Pinned in Task 1, Step 11.
3. A repository without the structure marker gets nothing from the `repo` hook: no output, exit 0. Pinned in Task 1, Steps 7 and 12.
4. When a pull request for the branch already exists, `build:finish` updates its description instead of opening a second one. Pinned in Task 4, Step 1.
5. A session that never invoked `conventions:engineering` does not commit without asking. Pinned by the without-plugin arm in Task 10, Step 4.

### The headless check

Tasks 1, 2 and 10 run this script.
It is scratch: save it as `tmp/headless-check.sh` (`tmp/` is gitignored) and never commit it.

```bash
#!/usr/bin/env bash
# One headless claude session in a fresh scratch repository outside the devkit.
# Usage: bash tmp/headless-check.sh with|without markdown|python
set -euo pipefail

devkit=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
arm=$1
task=$2

case $task in
markdown) prompt="Add the sentence 'Contributions are welcome.' as a new paragraph at the end of README.md." ;;
python) prompt="Create the file orders/order.py with an Order value type that has an id (string), a quantity (integer) and a method that returns a copy with a new quantity." ;;
*)
  echo "unknown task: $task" >&2
  exit 2
  ;;
esac

plugins=()
case $arm in
with) plugins=(--plugin-dir "$devkit/plugins/conventions" --plugin-dir "$devkit/plugins/writing") ;;
without) ;;
*)
  echo "unknown arm: $arm" >&2
  exit 2
  ;;
esac

dir=$(mktemp -d)
cd "$dir"
git init -q -b main
git config user.email check@example.com
git config user.name Check
printf '# Probe\n\nA scratch repository.\n' >README.md
git add README.md
git commit -q -m "chore: initial commit"

claude -p "$prompt" --setting-sources project "${plugins[@]}" \
  --allowedTools "Bash Edit Read Write Glob Grep Skill" \
  --output-format stream-json --verbose </dev/null >"$dir.jsonl" 2>"$dir.err"

skills=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill' "$dir.jsonl" | paste -sd, -)
printf 'arm=%s task=%s dir=%s\n' "$arm" "$task" "$dir"
printf 'skills: %s\n' "${skills:-none}"
printf 'branch: %s\n' "$(git branch --show-current)"
printf 'commits on main: %s\n' "$(git rev-list --count main)"
printf 'commits off main: %s\n' "$(git rev-list --count --branches --not main)"
printf 'new commit: %s\n' "$(git log -1 --format=%s --branches --not main)"
printf 'uncommitted: %s\n' "$(git status --short | paste -sd, -)"
```

A run passes when:

| Arm | Task | Passes when |
| --- | --- | --- |
| `with` | `markdown` | `skills` contains `conventions:engineering`; `branch` is not `main`; `commits on main: 1`; `commits off main: 1`; `new commit` matches `^[a-z]+(\([a-z0-9,-]+\))?!?:\s`; `uncommitted` is empty |
| `with` | `python` | the same, and `skills` also contains `conventions:python` |
| `without` | either | `branch: main`; `commits on main: 1`; `commits off main: 0`; `uncommitted` is not empty |

### Task 1: The conventions reach the agent

**Files:**

- Modify: `scripts/validate-marketplace.sh:97-101`
- Modify: line 3 of `plugins/conventions/skills/{adr,documents,engineering,markdown,nix,python,shell,typescript}/SKILL.md`
- Create: `plugins/conventions/hooks/hooks.json`, `plugins/conventions/hooks/session-start.sh`, `plugins/conventions/hooks/session-start.txt`
- Modify: `plugins/conventions/README.md`, `plugins/conventions/.claude-plugin/plugin.json`, `plugins/conventions/CHANGELOG.md`, `.claude-plugin/marketplace.json`
- Modify: `scripts/render-plugin-list.sh:33-35`, `README.md` (the generated table and line 131)
- Modify: `plugins/repo/hooks/session-start.sh`, `plugins/repo/README.md:15-18`, `plugins/repo/.claude-plugin/plugin.json`, `plugins/repo/CHANGELOG.md`
- Delete: `plugins/repo/hooks/session-start.txt`
- Modify: `docs/conventions/prerequisites.md:52`, `docs/TODO.md`

**Interfaces:**

- Produces: descriptions ending in "Invoke before ...", which Task 2's check relies on to get `conventions:engineering` invoked; the hook line "/build:finish to push the branch and open the pull request", which Tasks 4 and 5 make true.

- [ ] **Step 1: Save the headless check and record the baseline**

Save the script from "The headless check" as `tmp/headless-check.sh`.
Run: `bash tmp/headless-check.sh with markdown`
Expected: `skills: none`, `branch: main`, `commits off main: 0`, `uncommitted:  M README.md`.

- [ ] **Step 2: Write the failing validator rule**

In `scripts/validate-marketplace.sh`, replace:

```bash
    # Convention skills load by file path and are never invoked by name.
    if [[ "$entry_name" == conventions ]]; then
      sed -n '2,/^---$/p' "$skill" | grep -qE '^paths:' || fail "$skill: conventions skills need a paths list in the frontmatter"
      sed -n '2,/^---$/p' "$skill" | grep -qE '^user-invocable:[[:space:]]*false' || fail "$skill: conventions skills need user-invocable: false"
    fi
```

with:

```bash
    # Convention skills have no slash command, and their body reaches the agent
    # only when it invokes them, so the description says when to do that.
    if [[ "$entry_name" == conventions ]]; then
      sed -n '2,/^---$/p' "$skill" | grep -qE '^paths:' || fail "$skill: conventions skills need a paths list in the frontmatter"
      sed -n '2,/^---$/p' "$skill" | grep -qE '^user-invocable:[[:space:]]*false' || fail "$skill: conventions skills need user-invocable: false"
      sed -n '2,/^---$/p' "$skill" | grep -qE '^description:.* Invoke before ' || fail "$skill: conventions skills need a description that ends with when to invoke them (Invoke before ...)"
    fi
```

- [ ] **Step 3: Run the validator to see it fail**

Run: `bash scripts/validate-marketplace.sh`
Expected: exit 1, eight `error:` lines ending in "need a description that ends with when to invoke them (Invoke before ...)", one per conventions skill, then `validate-marketplace: 8 error(s)`.

- [ ] **Step 4: Rewrite the eight descriptions**

Replace line 3 (the `description:` line) of each file with exactly:

| File | Line 3 |
| --- | --- |
| `plugins/conventions/skills/adr/SKILL.md` | `description: Lyngon conventions for architecture decision records under docs/adr/. Invoke before writing or editing an ADR.` |
| `plugins/conventions/skills/documents/SKILL.md` | `description: Lyngon conventions for the standard repository documents CLAUDE.md, AGENTS.md, CONCEPTS.md, INTENT.md and README.md, at the root and in packages. Invoke before writing or editing one of them.` |
| `plugins/conventions/skills/engineering/SKILL.md` | `description: Lyngon engineering conventions for every change in every repository, covering how to decide, change, test, commit, push and open pull requests. Invoke before any engineering work, before the first edit of a session.` |
| `plugins/conventions/skills/markdown/SKILL.md` | `description: Lyngon Markdown writing conventions. Invoke before writing or editing any Markdown file.` |
| `plugins/conventions/skills/nix/SKILL.md` | `description: Lyngon Nix and devenv conventions. Invoke before writing or editing a Nix file or devenv.yaml.` |
| `plugins/conventions/skills/python/SKILL.md` | `description: Lyngon Python conventions. Invoke before writing or editing a Python file, stub or notebook.` |
| `plugins/conventions/skills/shell/SKILL.md` | `description: Lyngon shell conventions. Invoke before writing or editing a shell script or a file under a scripts/ directory.` |
| `plugins/conventions/skills/typescript/SKILL.md` | `description: Lyngon TypeScript and JavaScript conventions. Invoke before writing or editing a TypeScript or JavaScript file.` |

No description may contain ": " after the key, since that breaks the YAML plain scalar.

- [ ] **Step 5: Run the validator to see it pass**

Run: `bash scripts/validate-marketplace.sh`
Expected: `validate-marketplace: ok`, exit 0.

- [ ] **Step 6: Create the conventions hook**

`plugins/conventions/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

`plugins/conventions/hooks/session-start.sh`, then `chmod +x plugins/conventions/hooks/session-start.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook of the conventions plugin: adds the text of
# session-start.txt to the session context. It says which devkit skills to
# invoke and when, and that no skill loads on its own, the conventions
# included. It has no matcher, so it runs for every SessionStart source.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

text=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line//\\/\\\\}
  line=${line//\"/\\\"}
  text+="$line\\n"
done <"$here/session-start.txt"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
```

`plugins/conventions/hooks/session-start.txt`, exactly these nine lines:

```text
This is a Lyngon repository. The devkit plugins provide skills; invoke them instead of working from memory. No skill loads on its own, the conventions skills included: a skill's text reaches you only when you invoke it.
- conventions:engineering before any engineering work, and the conventions skill for a file's kind before editing that file.
- /discover:brainstorm to toss ideas around without writing anything.
- /discover:approach before building anything that has more than one reasonable design; it classifies the work and gates implementation on approval.
- /build:plan once a design is approved, then /build:delegate (or /build:execute) to build it and /build:finish to push the branch and open the pull request.
- practice:tdd, practice:debug, practice:verify and review:receive whenever their description matches; process skills come before implementation.
- /writing:unslop before handing over prose.
The flow between these skills, and where the user decides, is WORKFLOW.md next to the approach and plan skills.
Terms are in CONCEPTS.md, decisions in docs/adr/, working rules in CLAUDE.md.
```

- [ ] **Step 7: Shrink the repo hook, failing check first**

Run: `bash -c 't=$(mktemp -d); CLAUDE_PROJECT_DIR=$t bash plugins/repo/hooks/session-start.sh; echo "exit $?"'`
Expected before the change: one line of JSON carrying the generic lines, then `exit 0`.

Replace `plugins/repo/hooks/session-start.sh` with:

```bash
#!/usr/bin/env bash
# SessionStart hook of the repo plugin: adds the text of
# session-start-structure.txt to the session context when the root CLAUDE.md
# says the repository follows the Lyngon structure, and prints nothing
# otherwise. The lines about which devkit skills to invoke come from the
# conventions plugin's own hook.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${CLAUDE_PROJECT_DIR:-$PWD}

grep -qsF "This repository follows the Lyngon structure" "$root/CLAUDE.md" || exit 0

text=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line//\\/\\\\}
  line=${line//\"/\\\"}
  text+="$line\\n"
done <"$here/session-start-structure.txt"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$text"
```

Then: `git rm plugins/repo/hooks/session-start.txt`

- [ ] **Step 8: Run the conventions hook**

Run: `bash plugins/conventions/hooks/session-start.sh | jq -r .hookSpecificOutput.additionalContext`
Expected: the nine lines of `session-start.txt`, exactly, followed by one empty line.

- [ ] **Step 9: Run shellcheck on both hook scripts**

Run: `prek run shellcheck --files plugins/conventions/hooks/session-start.sh plugins/repo/hooks/session-start.sh`
Expected: `Passed`.

- [ ] **Step 10: Pin Review Focus 1, both ways**

Run: `jq -e '.hooks.SessionStart | length == 1 and (.[0] | has("matcher") | not)' plugins/conventions/hooks/hooks.json`
Expected: `true`, exit 0.
Control: `jq '.hooks.SessionStart[0].matcher = "startup"' plugins/conventions/hooks/hooks.json | jq -e '.hooks.SessionStart | length == 1 and (.[0] | has("matcher") | not)'`
Expected: `false`, exit 1.

- [ ] **Step 11: Pin Review Focus 2, both ways**

Run:

```bash
bash -c 't=$(mktemp -d); cp plugins/conventions/hooks/session-start.sh "$t/"; printf "%s\n" "a \"quoted\" word" "a back\\slash" >"$t/session-start.txt"; bash "$t/session-start.sh" | jq -r .hookSpecificOutput.additionalContext'
```

Expected: `a "quoted" word`, then `a back\slash`, then an empty line.
Control, with the two escaping lines removed from a copy of the script:

```bash
bash -c 't=$(mktemp -d); grep -v "line=\${line//" plugins/conventions/hooks/session-start.sh >"$t/session-start.sh"; printf "%s\n" "a \"quoted\" word" >"$t/session-start.txt"; bash "$t/session-start.sh" | jq -r .hookSpecificOutput.additionalContext'
```

Expected: a `jq` parse error and a non-zero exit.

- [ ] **Step 12: Pin Review Focus 3, both ways**

Run: `bash -c 't=$(mktemp -d); CLAUDE_PROJECT_DIR=$t bash plugins/repo/hooks/session-start.sh; echo "exit $?"'`
Expected: only `exit 0`.
Run: `bash -c 't=$(mktemp -d); echo "This repository follows the Lyngon structure." >"$t/CLAUDE.md"; CLAUDE_PROJECT_DIR=$t bash plugins/repo/hooks/session-start.sh | jq -r .hookSpecificOutput.additionalContext'`
Expected: the line of `plugins/repo/hooks/session-start-structure.txt`, then an empty line.

- [ ] **Step 13: Update the documents that describe the conventions and the hooks**

`plugins/conventions/README.md`: replace

```markdown
Each skill carries `paths` in its frontmatter and `user-invocable: false`: it loads on its own when the agent works on a matching file and is never invoked by name.
The bodies are short on purpose, because they ride along with every matching edit.
```

with

```markdown
Each skill carries `paths` and `user-invocable: false` in its frontmatter, and a description that ends with when to invoke it.
A skill's body reaches the agent only when the agent invokes it; `paths` does not load it.
The plugin's `SessionStart` hook says so at the start of every session, together with which devkit skills to invoke and when.
The bodies are short on purpose, because agents invoke them in almost every session.
```

In the same file, change the table header `| Skill | Loads for |` to `| Skill | Invoke before working on |`, and insert before `## Install`:

```markdown
## Hooks

- `SessionStart`: prints `hooks/session-start.txt`, which says which devkit skills to invoke and when, and that no skill loads on its own, the conventions included.

```

`plugins/repo/README.md`: replace the `## Hooks` section (lines 15 to 18) with

```markdown
## Hooks

- `SessionStart`: in a repository whose root `CLAUDE.md` says it follows the Lyngon structure, prints `hooks/session-start-structure.txt`, which says to create every package with `/repo:add-package`; elsewhere it prints nothing.
  The lines about which devkit skills to invoke come from the `conventions` plugin's hook.
```

The `description` of `conventions` in both `plugins/conventions/.claude-plugin/plugin.json` and its entry in `.claude-plugin/marketplace.json` becomes:
`Organization-wide conventions, invoked by the agent before it works: engineering rules for every change, one skill per language, and the rules for Markdown, ADRs and the standard documents.`

`scripts/render-plugin-list.sh`: replace

```bash
        # Skills with user-invocable: false load by file path and have no slash command.
        if sed -n '2,/^---$/p' "$skill/SKILL.md" | grep -qE '^user-invocable:[[:space:]]*false'; then
          skills+="\`$(basename "$skill")\` (by path), "
```

with

```bash
        # Skills with user-invocable: false have no slash command; the agent invokes them.
        if sed -n '2,/^---$/p' "$skill/SKILL.md" | grep -qE '^user-invocable:[[:space:]]*false'; then
          skills+="\`$(basename "$skill")\` (agent-invoked), "
```

Run: `bash scripts/render-plugin-list.sh`
Expected: exit 1 with `render-plugin-list: README.md plugin table regenerated; stage it and commit again`; the `conventions` row now reads `(agent-invoked)` and carries the new description.
Run it again. Expected: no output, exit 0.

`README.md` line 131: replace

```markdown
- Conventions load on their own by file path from the `conventions` plugin: engineering rules for every file, one skill per language, and the rules for Markdown, ADRs and the standard documents. Nothing is copied into the repository.
```

with

```markdown
- Conventions come from the `conventions` plugin, whose session hook and skill descriptions tell agents to invoke them before working: engineering rules for every change, one skill per language, and the rules for Markdown, ADRs and the standard documents. Nothing is copied into the repository.
```

`docs/conventions/prerequisites.md` line 52: replace

```markdown
Skills that load without being asked, through `paths`, and hooks that run at session start are where unconditional text does the most damage.
```

with

```markdown
Skills whose description asks to be invoked for every matching file, and hooks that run at session start, are where unconditional text does the most damage.
```

`docs/TODO.md`: delete the Deferred item that starts `- 2026-09-23: The \`SessionStart\` hook that tells agents which skills to invoke lives in \`repo\``.

- [ ] **Step 14: Versions and changelogs**

`conventions` 0.5.1 to 0.6.0; add at the top of `plugins/conventions/CHANGELOG.md`, below the preamble:

```markdown
## 0.6.0 - 2026-09-29

- Every skill's description ends with when to invoke it ("Invoke before ..."), instead of saying the skill loads automatically. A skill's body reaches the agent only when the agent invokes it, and `paths` does not load it, so no convention reached an agent before. `validate-marketplace` requires the wording.
- A `SessionStart` hook says which devkit skills to invoke and when, and that no skill loads on its own, the conventions included. It takes over the generic lines of the `repo` plugin's hook, so every repository that installs `core` gets them.
```

`repo` 0.6.3 to 0.7.0; add at the top of `plugins/repo/CHANGELOG.md`:

```markdown
## 0.7.0 - 2026-09-29

- The `SessionStart` hook prints only the structure line, and only in a repository that follows the Lyngon structure. The generic lines moved to the `conventions` plugin's hook, which reaches every repository that installs `core`; the line saying that conventions load on their own was wrong and is gone.
```

- [ ] **Step 15: Headless check, invocation now expected**

Run: `bash tmp/headless-check.sh with markdown` and `bash tmp/headless-check.sh with python`
Expected: `skills` contains `conventions:engineering` in both, and `conventions:python` in the second.
Whether they commit is Task 2's concern; record what the runs show in the task report.

- [ ] **Step 16: Run the hooks on the changed files**

Run: `git add -N plugins/conventions/hooks && prek run --all-files`
Expected: every hook `Passed` or `Skipped`.

- [ ] **Step 17: Commit**

```bash
git add -A plugins/conventions plugins/repo scripts/validate-marketplace.sh scripts/render-plugin-list.sh .claude-plugin/marketplace.json README.md docs/conventions/prerequisites.md docs/TODO.md
git commit -m "feat(conventions,repo): tell agents to invoke the conventions" -m "A skill's body loads only when the agent invokes it; paths does not load it, and every conventions description said it loaded automatically, so no convention reached an agent. The descriptions now end with when to invoke them, the validator requires that, and a SessionStart hook in conventions, which is in core, takes over the generic lines of the repo hook."
```

### Task 2: The standing instructions

**Files:**

- Modify: `plugins/conventions/skills/engineering/SKILL.md` (the `## Handing over` section)
- Modify: `plugins/conventions/.claude-plugin/plugin.json`, `plugins/conventions/CHANGELOG.md`

**Interfaces:**

- Consumes: Task 1's engineering description, which gets the skill invoked.
- Produces: the ask-first list "a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish", which Task 5 copies into `WORKFLOW.md` and the executors, verbatim.

- [ ] **Step 1: Headless check, failing**

Run: `bash tmp/headless-check.sh with markdown`
Expected: `skills` contains `conventions:engineering`, and `commits off main: 0` with `README.md` uncommitted.
If this run commits anyway, Task 1 alone changed the behaviour: record that in the task report and continue.

- [ ] **Step 2: Replace the section**

In `plugins/conventions/skills/engineering/SKILL.md`, replace

```markdown
## Handing over

- Run the repository's full check before handing over. Never disable or skip a check to make it pass.
- Report faithfully: failing tests with their output, skipped steps by name, done things plainly.
- Commit messages follow Conventional Commits, one concern per commit.
```

with

```markdown
## Committing and handing over

These are the user's standing instructions: they count as being asked to commit, push and open a pull request.

- Work on a feature branch named `<type>/<slug>`, after the Conventional Commits type of its main change. On the default branch, create one first.
- Commit without asking whenever a concern is done: one concern per commit, in Conventional Commits form. Commits not yet pushed may be amended or reordered.
- When the work is done and the full check passes, push the branch and open a pull request without asking. The user reviews the pull request and decides the merge.
- Run the full check before every push. Never disable, skip or weaken a check or hook to get past it.
- Never rewrite pushed history without asking; fixes after a push are new commits.
- Ask before any other effect outside the branch: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish.
- Without a remote, commit and report. With a remote but no forge CLI, push and hand over the pull request link the forge printed.
- Report faithfully: failing checks with their output, skipped steps by name, done things plainly.
```

- [ ] **Step 3: Headless check, passing**

Run: `bash tmp/headless-check.sh with markdown`
Expected: every `with markdown` criterion of the pass table holds.

- [ ] **Step 4: Version and changelog**

`conventions` 0.6.0 to 0.7.0; add at the top of `plugins/conventions/CHANGELOG.md`:

```markdown
## 0.7.0 - 2026-09-29

- `engineering` carries the user's standing instructions, replacing its "Handing over" section: commit on a feature branch without asking, one concern per commit; push and open a pull request once the full check passes; ask before a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release or a publish. The text says it counts as being asked, which overrides an agent's default of committing only on request.
```

- [ ] **Step 5: Run the hooks on the changed files**

Run: `prek run --files plugins/conventions/skills/engineering/SKILL.md plugins/conventions/.claude-plugin/plugin.json plugins/conventions/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`; `validate prerequisites` passes, since the new text names no baseline or structure term.

- [ ] **Step 6: Commit**

```bash
git add plugins/conventions
git commit -m "feat(conventions): make commit, push and pull request standing instructions"
```

### Task 3: ADR 0016 names the pull request as the second gate

**Files:**

- Modify: `docs/adr/0016-planned-work-is-reviewed-at-two-gates.md` (in place, by the user's exception; file name and title stay)

**Interfaces:**

- Consumes: Task 2's ask-first list, quoted verbatim.

- [ ] **Step 1: Failing check**

Run: `git grep -n -E 'finished branch|commit when told' -- docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`
Expected: two lines, 4 and 15.

- [ ] **Step 2: Rewrite the ADR**

Replace the whole file with:

```markdown
# Planned work is reviewed at two gates, the plan and the branch, and the plan lives on the branch until it lands

Reviewing every commit made the owner the bottleneck of agent-driven work, and the vendored build workflow (superpowers' `writing-plans`, `executing-plans` and `subagent-driven-development`) commits once per task and keys its recovery ledger on those commits.
We review planned work at two gates: the design and the task list before execution (`/discover:approach`, `/build:plan`), and the pull request afterwards, read from the executor's "Rulings I made" and "Deferred minors" lists at the top of its description; between the gates the executor commits per task on a feature branch without asking, and per-task scrutiny is a reviewer subagent's job (`/build:delegate` by default).
The agent pushes the branch and opens the pull request without asking once the full check passes, and merging stays the owner's decision.
Work without a plan follows the same rule, with the pull request as its only gate: the agent commits each concern on a feature branch as it goes, without waiting for a file review.
The plan is one file, `docs/plans/YYYY-MM-DD-<slug>.md`, with the design and the tasks, committed on the branch so a reviewer or a fresh session reads both together, and removed by `/build:finish` before the push because git history holds the work and ADRs hold the decisions; the execution ledger lives in `tmp/build/<slug>/`, the agent scratch directory, never in git.

## Considered options

- Keep per-commit review: the owner's attention bounds throughput, and a ledger keyed on task commits cannot wait for it.
- Keep file review before commit for work without a plan: it keeps the owner in series with every commit, and holding commits mixes concerns in one working tree (pull request 2 held twelve, rebuilt into commits afterwards).
- Keep plans under `docs/` after the work lands: a stale plan contradicts the code and becomes a second place to maintain what the code already says.
- Keep plans in `tmp/`: not on the branch, so the reviewer sees tasks without the design and a fresh session cannot pick the plan up.

## Consequences

- The standing instructions to commit, push and open the pull request live in `conventions:engineering`, because only a plugin reaches every repository that uses the devkit; the `conventions` session hook and the skill descriptions make agents invoke it. Those instructions also list what still waits for the owner: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish.
- `build` declares `documents` and is in `core`; the ledger location does not raise it, since `tmp/` is the scratch directory of every repository the `repo` plugin sets up and the workspace script ignores its own directory where `tmp/` is not ignored.
- A decision made while planning still becomes an ADR before the plan file is removed; `/build:finish` checks the design section for one.
```

- [ ] **Step 3: Passing check**

Run the Step 1 command again.
Expected: no output, exit 1.

- [ ] **Step 4: Run the hooks and commit**

Run: `prek run --files docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`
Expected: every hook `Passed` or `Skipped`.

```bash
git add docs/adr/0016-planned-work-is-reviewed-at-two-gates.md
git commit -m "docs(adr): review all work on its pull request"
```

### Task 4: `build:finish` pushes and opens the pull request

**Files:**

- Modify: `plugins/build/skills/finish/SKILL.md`, `plugins/build/skills/finish/UPSTREAM.md`
- Modify: `plugins/build/README.md:12`, `plugins/build/.claude-plugin/plugin.json`, `plugins/build/CHANGELOG.md`

**Interfaces:**

- Consumes: the standing instructions of Task 2, which `finish` names as the reason it does not ask.
- Produces: `## Step 5: Push and open the pull request` and `## Step 6: Other outcomes, on request`, which Task 5's texts refer to as "the pull request that `build:finish` opens".

- [ ] **Step 1: Failing check, pinning Review Focus 4**

Run:

```bash
bash -c 'f=plugins/build/skills/finish/SKILL.md; for p in "Which option?" "integration menu" "Confirm before merging"; do grep -qF "$p" "$f" && echo "still there: $p"; done; for p in "## Step 5: Push and open the pull request" "already exists" "Decisions for you" "parent of the plan-removal commit" "## Step 6: Other outcomes, on request"; do grep -qF "$p" "$f" || echo "missing: $p"; done; true'
```

Expected: three `still there:` lines and five `missing:` lines.

- [ ] **Step 2: Frontmatter, overview and Step 1**

Replace the `description` in the frontmatter with:

```yaml
description: >-
  Finish a development branch: run the repository's full check, remove the plan file
  in a final commit, push the branch and open a pull request without asking (merging
  locally or keeping the branch only on request), and keep the worktree until the
  work lands. Use when a plan's tasks are complete and the whole-branch review is
  clean, or when any feature branch is done: "the plan is done, wrap up the branch",
  "finish this branch", "open the pull request". Not for committing a single change.
```

Replace `Core principle: verify the full check, remove the plan, detect the environment, present options, execute the choice, clean up.` with `Core principle: verify the full check, remove the plan, detect the environment, push and open the pull request, and clean up only what has landed.`

In Step 1, replace `If it fails, report the failures and stop; the menu comes after a green check:` with `If it fails, report the failures and stop; the push comes after a green check:`.

- [ ] **Step 3: Replace Steps 3 to 6**

Replace everything from the line `## Step 3: Detect the environment` up to, not including, the line `## Step 7: Clean up the plan workspace and the worktree` with:

````markdown
## Step 3: Detect the environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace: a local merge changes
# directory before cleanup (Step 7) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
git remote -v
```

This determines how the branch is pushed and how cleanup works:

| State | Push | Cleanup |
| --- | --- | --- |
| `GIT_DIR == GIT_COMMON` (normal repository) | The branch, with its upstream | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | The branch, with its upstream | Provenance-based (see Step 7) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | HEAD as a new branch; no local merge | Externally managed, leave in place |

Without a remote there is nothing to push; Step 5 says what to do instead.

## Step 4: Determine the base branch

The base branch is whatever this work forked from, usually named in the plan, the conversation, or the branch's upstream, and otherwise the remote's default branch.
For the pull request, take it without asking: a wrong base is changed on the forge in one step.
A local merge (Step 6, on request) is different: first ask "This branch split from [your best guess], is that correct?", because merging into the wrong base is expensive to undo.

## Step 5: Push and open the pull request

Pushing the feature branch and opening its pull request are the user's standing instructions: do both without asking.
The user reviews the pull request and decides the merge.
Merge locally or keep the branch instead only when the user asked for that (Step 6).

Without a remote, there is nothing to push: report the branch and its commits, keep the worktree and the plan workspace, and stop.

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

A rejected push means the remote moved.
Investigate, integrate the remote commits (rebasing only commits that were never pushed), run the full check again and push again.
Force-push only when the user asks for it.

Then open the pull request (or merge request) against the base branch with the forge's CLI.
When a pull request for this branch already exists, the push has updated it: update its description instead of opening another.
Without a forge CLI, or with one that is not signed in, hand over the creation link the forge printed on push.
Follow the repository's pull request template and conventions if present.

The description carries, in this order:

1. What changed and why, in a short paragraph.
2. "Decisions for you": anything the user must decide, or "none".
3. When an executor produced the branch, its "Rulings I made" and "Deferred minors" lists, and a link to the plan file at the parent of the plan-removal commit, since the plan does not show in the pull request's diff.
4. Review findings nobody fixed.
5. Verification: the full check command and its result, and any other evidence by name.

Report the URL to the user.

Keep the worktree and the plan workspace: the work has not landed.
Changes asked for on the pull request are made in the worktree as new commits and pushed after the full check; update the description when its lists change.

The merge then happens on the forge, and the local base branch does not follow it.
End your report with the landing steps for after the merge, with the paths and names filled in and the lines that do not apply left out, so the user or the next session can run them:

```bash
cd <main repository root>
git switch <base-branch>
git pull --ff-only
rm -rf <plan workspace>                # when Step 2 resolved one
git worktree remove <worktree path>    # only under .worktrees/ or worktrees/, as in Step 7
git branch -d <feature-branch>         # after the worktree: git refuses to delete a checked-out branch
```

A forge that squashed or rebased the pull request leaves the local branch unmerged in git's eyes, so `git branch -d` refuses it.
Check that the pull request shows as merged, then delete it with `-D`.

## Step 6: Other outcomes, on request

Only when the user asked for one of these instead of the pull request.

### Merge locally

```bash
# Get the main repository root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first; verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify the full check on the merged result
<full check>
```

If the check fails on the merged result: stop, leave the worktree and branch in place, and investigate; nothing has been pushed, so the merge is local and recoverable.

Once the merged result is green: clean up the plan workspace and the worktree (Step 7), then delete the branch:

```bash
git branch -d <feature-branch>
```

### Keep as it is

Report: "Keeping branch [name]. Worktree preserved at [path]."

### If the user asks to discard the work

This path exists only as a response to an explicit request to throw the work away.
Confirm first:

```text
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation.
When it arrives:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the plan workspace and the worktree (Step 7), and force-delete the branch:

```bash
git branch -D <feature-branch>
```

````

- [ ] **Step 4: Step 7, the quick reference and the rationalizations**

In Step 7, replace the two lines

```markdown
Runs for Option 1 and confirmed discards.
Options 2 and 3 always preserve the worktree and the plan workspace, since the work has not landed.
```

with

```markdown
Runs for a local merge and a confirmed discard.
The pull request and a kept branch always preserve the worktree and the plan workspace, since the work has not landed.
```

Replace the quick reference table with:

```markdown
| Outcome | Merge | Push | Keep worktree and plan workspace | Clean up branch |
| --- | --- | --- | --- | --- |
| Pull request (the default) | - | yes | yes | - |
| Pull request, after the forge merged it (landing steps) | fast-forward the base (`git pull --ff-only`) | - | - | yes |
| Merge locally (on request) | yes | - | - | yes |
| Keep as it is (on request) | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (force) |
```

In the rationalization table, replace the row

```markdown
| "They obviously want it merged" | Integration is the user's decision. Present the menu and wait. |
```

with

```markdown
| "They obviously want it merged" | Merging is the user's decision. Open the pull request; merge locally only when they ask. |
| "Let me ask before pushing" | Pushing the feature branch and opening its pull request are the user's standing instructions. Asking puts them back in series with the work. |
| "The pull request is up, I'll amend the commit to fix a typo" | Pushed history is not rewritten without asking. Fix it in a new commit and push after the full check. |
```

and replace the row

```markdown
| "They seem done with this feature, I'll offer to discard it" | The menu is complete as written. Discard happens only when the user asks for it in so many words. |
```

with

```markdown
| "They seem done with this feature, I'll offer to discard it" | Discard happens only when the user asks for it in so many words. |
```

- [ ] **Step 5: Provenance record**

In `plugins/build/skills/finish/UPSTREAM.md`:

- Under "Why it is here", replace `then the user chooses merge, pull request or keep.` with `then the branch pushed and its pull request opened for the user's review.`
- Append to "Local patches":

```markdown
- The integration menu is gone. Step 5 pushes the branch and opens the pull request without asking, as the user's standing instructions say; merging locally, keeping the branch and discarding moved to Step 6, "Other outcomes, on request". Without a remote it reports and keeps the branch, without a forge CLI it hands over the creation link, and an existing pull request gets its description updated. The description lists what changed and why, decisions for the user, the executor's rulings and deferred minors with a link to the plan at the parent of the plan-removal commit, unfixed review findings, and the verification. Step 3's table says how the branch is pushed instead of which menu to show; Step 4 takes the base without asking for a pull request and asks only before a local merge. The description, the overview, Step 1's last line, Step 7's opening, the quick reference and the rationalization table follow, with rows for asking before the push and for amending a pushed commit.
```

- Append to "Review notes":

```markdown
- 2026-09-29: pushing and opening a pull request no longer wait for a menu choice (ADR 0016 and the standing instructions in `conventions:engineering`); merging, force-pushing and discarding still wait for the user.
```

- [ ] **Step 6: README, version and changelog**

`plugins/build/README.md` line 12 becomes:
`- \`/build:finish\`: run the full check, offer the deferred findings for \`docs/TODO.md\`, remove the plan file, push the branch and open the pull request; merging locally or keeping the branch only on request.`

`build` 0.3.0 to 0.4.0; add at the top of `plugins/build/CHANGELOG.md`:

```markdown
## 0.4.0 - 2026-09-29

- `finish` pushes the branch and opens the pull request without asking instead of presenting a menu, and merges locally or keeps the branch only on request. The description carries what changed, decisions for the user, the executor's rulings and deferred minors with a link to the plan, unfixed findings and the verification. An existing pull request gets its description updated; without a remote the branch is kept, and without a forge CLI the creation link is handed over.
```

- [ ] **Step 7: Passing check**

Run the Step 1 command again.
Expected: no output.

- [ ] **Step 8: Run the hooks and commit**

Run: `prek run --files plugins/build/skills/finish/SKILL.md plugins/build/skills/finish/UPSTREAM.md plugins/build/README.md plugins/build/.claude-plugin/plugin.json plugins/build/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/build
git commit -m "feat(build): push and open the pull request in finish without asking"
```

### Task 5: The flow names the pull request as the second gate

**Files:**

- Modify: `shared/WORKFLOW.md`
- Modify: `plugins/build/skills/plan/SKILL.md:208-209`, `plugins/build/skills/execute/SKILL.md:28,37,221,247`, `plugins/build/skills/delegate/SKILL.md:26,37,336,399,406,412,435`, and the `UPSTREAM.md` of each
- Modify: `plugins/build/README.md:14`, `plugins/build/.claude-plugin/plugin.json`, `plugins/build/CHANGELOG.md`
- Modify: `plugins/discover/skills/approach/SKILL.md:32`, `plugins/discover/skills/approach/UPSTREAM.md`, `plugins/discover/.claude-plugin/plugin.json`, `plugins/discover/CHANGELOG.md`
- Modify: `README.md:14,59`

**Interfaces:**

- Consumes: Task 2's ask-first list and Task 4's Step 5.

- [ ] **Step 1: Failing check**

Run:

```bash
git grep -n -E 'the finished branch|presents the options|before merg|integration menu|push to a shared branch|hands the branch back' -- shared/WORKFLOW.md plugins/build/skills/plan/SKILL.md plugins/build/skills/execute/SKILL.md plugins/build/skills/delegate/SKILL.md plugins/build/README.md plugins/discover/skills/approach/SKILL.md README.md
```

Expected: 21 lines (Task 4 already changed `plugins/build/README.md` line 12).

- [ ] **Step 2: `shared/WORKFLOW.md`**

In the table, replace the three rows

```markdown
| A bug | `practice:debug`, then `practice:tdd` for the regression test, `practice:verify` before claiming it fixed |
| A small change with an obvious design | Do it; `practice:tdd` and `practice:verify` apply on their own |
```

and

```markdown
| A finished branch, however it was made | `/build:finish` |
```

with

```markdown
| A bug | `practice:debug`, then `practice:tdd` for the regression test, `practice:verify` before claiming it fixed, then `/build:finish` |
| A small change with an obvious design | Do it; `practice:tdd` and `practice:verify` apply on their own; then `/build:finish` |
```

and

```markdown
| A finished branch, however it was made | `/build:finish` pushes it and opens the pull request |
```

Replace the steps of "Bounded change" with:

```markdown
1. `/discover:approach` asks the clarifying questions that matter in one round and presents a short design in chat: approach, files touched, testing.
2. **Gate**: the user says yes to that design.
3. Implement with `practice:tdd`, committing each concern as it is done; `practice:verify` before every claim.
4. `/review:request` before the pull request.
5. `/build:finish` runs the full check, pushes the branch and opens the pull request.
6. **Gate**: the user reviews the pull request and merges it or asks for changes.
7. `review:receive` handles the feedback; the fixes are new commits, pushed after the full check.
```

In "Architectural change", replace steps 5 to 7 with:

```markdown
5. `/build:finish` runs the full check, removes the plan file, pushes the branch and opens the pull request.
6. **Gate 2**: the user reviews the pull request, starting from the executor's "Rulings I made" and "Deferred minors" lists in its description, and merges it or asks for changes.
7. `review:receive` handles the feedback; the fixes go through `practice:tdd` and are pushed as new commits after the full check.
```

In "Who decides what", replace

```markdown
The user decides at the gates: the classification (they can override it), the design, the plan and the executor, and what happens to the finished branch.
```

with

```markdown
The user decides at the gates: the classification (they can override it), the design, the plan and the executor, and whether the pull request merges.
```

replace

```markdown
Four things always stop an executor for the user: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to a shared branch, a publish), and a plan so broken that every path forward is a guess.
```

with

```markdown
Four things always stop an executor for the user: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish), and a plan so broken that every path forward is a guess.
Pushing the feature branch and opening its pull request are not among them.
```

and replace

```markdown
A per-commit human review is not part of any flow; the two gates replace it.
```

with

```markdown
No flow has a per-commit or per-file human review: the agent commits on a feature branch without asking, and the user reviews the pull request.
The standing instructions for commits, pushes and pull requests are in `conventions:engineering`.
```

- [ ] **Step 3: `build:plan`**

Replace lines 208 and 209:

```markdown
This is the first of the user's two review gates; the second is the finished branch.
Between the two they are not asked anything: the executor rules on conflicts, records its rulings in a ledger, and presents them with the finished branch.
```

with

```markdown
This is the first of the user's two review gates; the second is the pull request that `build:finish` opens.
Between the two they are not asked anything: the executor rules on conflicts, records its rulings in a ledger, and presents them in the pull request description.
```

Append to "Local patches" in `plugins/build/skills/plan/UPSTREAM.md`:

```markdown
- The execution handoff names the pull request that `build:finish` opens as the second gate, and says the rulings are presented in its description.
```

- [ ] **Step 4: `build:execute` and `build:delegate`**

In both `SKILL.md` files:

- Replace `They review at two gates only: the plan before execution, and the finished branch afterwards.` with `They review at two gates only: the plan before execution, and the pull request afterwards.`
- In the "Five things stop you" paragraph, replace `(a merge, a push to a shared branch, a publish)` with `(a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish; pushing the feature branch and opening its pull request are not among them)`.

In `plugins/build/skills/execute/SKILL.md`:

- Replace `and the user decides whether that is enough before merge.` with `and the user decides whether that is enough when they review the pull request.`
- Replace `the user reads the finished branch starting from these two lists.` with `` `build:finish` puts these two lists at the top of the pull request description, and the user reads the pull request starting from them.``

In `plugins/build/skills/delegate/SKILL.md`:

- Line 336: replace `so it can triage which must be fixed before merge.` with `so it can triage which must be fixed before the pull request.`
- Line 399: replace `so it can triage which must be fixed before merge and weigh the calls you made` with `so it can triage which must be fixed before the pull request and weigh the calls you made`.
- Line 406: replace `residual load-bearing findings reach the user in the rulings list, when \`build:finish\` presents the options.` with `residual load-bearing findings reach the user in the rulings list, at the top of the pull request description that \`build:finish\` writes.`
- Line 412: replace `the user reads the finished branch starting from these two lists, and reworks whatever you got wrong.` with `` `build:finish` puts these two lists at the top of the pull request description, and the user reads the pull request starting from them and asks for changes where you got it wrong.``
- Line 435: replace `| "Let me check in before the next task" | The user reviews the plan and the finished branch, nothing in between. Only the five stops stop you. |` with `| "Let me check in before the next task" | The user reviews the plan and the pull request, nothing in between. Only the five stops stop you. |`

Append to "Local patches" in `plugins/build/skills/execute/UPSTREAM.md`:

```markdown
- The second gate is the pull request that `build:finish` opens, and the final message's two lists go to the top of its description. The stop list's side effects are the ones the user's standing instructions leave to them (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish); pushing the feature branch and opening its pull request are not among them.
```

Append to "Local patches" in `plugins/build/skills/delegate/UPSTREAM.md`:

```markdown
- The second gate is the pull request that `build:finish` opens, and the final message's two lists and residual findings go to the top of its description. The stop list's side effects are the ones the user's standing instructions leave to them (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish); pushing the feature branch and opening its pull request are not among them. Deferred minors are triaged for what must be fixed before the pull request.
```

- [ ] **Step 5: `discover:approach`**

In `plugins/discover/skills/approach/SKILL.md`, replace `When the review and build plugins are installed, \`review:request\` before merging and \`build:finish\` to integrate the branch.` with `When the review and build plugins are installed, \`review:request\` before the pull request and \`build:finish\` to push the branch and open it.`

Append to "Local patches" in `plugins/discover/skills/approach/UPSTREAM.md`:

```markdown
- The bounded path runs `review:request` before the pull request and `build:finish` to push the branch and open it, where it said "before merging" and "to integrate the branch".
```

- [ ] **Step 6: READMEs**

`plugins/build/README.md` line 14 becomes:
`The user reviews at two gates: the plan before execution, and the pull request afterwards, starting from the executor's "Rulings I made" and "Deferred minors" lists in its description.`

`README.md` line 14 becomes:
`- Work is reviewed on its pull request, which the agent opens without asking; planned work is also reviewed at the plan. Not commit by commit.`

`README.md` line 59: replace `and \`/build:finish\` hands the branch back for the second and last review.` with `and \`/build:finish\` pushes the branch and opens its pull request for the second and last review.`

- [ ] **Step 7: Versions and changelogs**

`build` 0.4.0 to 0.5.0; add at the top of `plugins/build/CHANGELOG.md`:

```markdown
## 0.5.0 - 2026-09-29

- `plan`, `execute` and `delegate` name the pull request as the user's second gate, and the executors no longer stop for pushing the feature branch or opening its pull request. `WORKFLOW.md` puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request.
```

`discover` 0.2.1 to 0.3.0; add at the top of `plugins/discover/CHANGELOG.md`:

```markdown
## 0.3.0 - 2026-09-29

- `approach` runs `review:request` before the pull request and `build:finish` to push the branch and open it. `WORKFLOW.md`, symlinked here, puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request.
```

- [ ] **Step 8: Passing check**

Run the Step 1 command again.
Expected: no output, exit 1.

- [ ] **Step 9: Run the hooks and commit**

Run: `prek run --all-files`
Expected: every hook `Passed` or `Skipped`.

```bash
git add shared/WORKFLOW.md plugins/build plugins/discover README.md
git commit -m "feat(build,discover): name the pull request as the second gate"
```

### Task 6: `review:request` before the pull request

**Files:**

- Modify: `plugins/review/skills/request/SKILL.md:3-8,25,67`, `plugins/review/skills/request/UPSTREAM.md`
- Modify: `plugins/review/README.md:9`, `plugins/review/.claude-plugin/plugin.json`, `plugins/review/CHANGELOG.md`

- [ ] **Step 1: Failing check**

Run: `bash -c 'git grep -n -E "before merg|before a merge|Before merging" -- plugins/review/skills/request/SKILL.md plugins/review/README.md; grep -c "go into the pull request description" plugins/review/skills/request/SKILL.md'`
Expected: three `git grep` lines (README line 9, SKILL lines 6 and 25), then `0`.

- [ ] **Step 2: Edit the skill**

Replace the frontmatter `description` with:

```yaml
description: >-
  Dispatch a fresh reviewer subagent with a crafted brief, a commit range and the plan or
  requirements, then act on its findings by severity. Use when a task or feature is complete
  and there is code to review: before opening a pull request ("get this reviewed before I
  open the pull request"), after each task in build:delegate, at the end of build:execute,
  or when stuck and wanting a fresh look at the code.
```

Replace `- Before merging to the main branch` with `- Before opening a pull request, in the bounded and architectural flows`.

Replace `- Note Minor issues for later.` with `- Note Minor issues for later; the ones nobody fixes go into the pull request description.`

Append to "Local patches" in `plugins/review/skills/request/UPSTREAM.md`:

```markdown
- The description and the mandatory list name opening a pull request where they named merging, and step 3 sends Minor findings that nobody fixes to the pull request description.
```

- [ ] **Step 3: README, version and changelog**

`plugins/review/README.md` line 9: replace `also on request before a merge.` with `also before a pull request is opened in the bounded flow, and on request.`

`review` 0.2.0 to 0.3.0; add at the top of `plugins/review/CHANGELOG.md`:

```markdown
## 0.3.0 - 2026-09-29

- `request` is mandatory before a pull request is opened rather than before a merge, and Minor findings that nobody fixes go into the pull request description.
```

- [ ] **Step 4: Passing check**

Run the Step 1 command again.
Expected: no `git grep` lines, then `1`.

- [ ] **Step 5: Run the hooks and commit**

Run: `prek run --files plugins/review/skills/request/SKILL.md plugins/review/skills/request/UPSTREAM.md plugins/review/README.md plugins/review/.claude-plugin/plugin.json plugins/review/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`; `validate prerequisites` passes, since the text names no document.

```bash
git add plugins/review
git commit -m "feat(review): request the review before the pull request"
```

### Task 7: `init` and `add-package` commit their work

**Files:**

- Modify: `plugins/repo/skills/init/SKILL.md` (step 5's opening, step 7)
- Modify: `plugins/repo/skills/add-package/SKILL.md` (step 7)
- Modify: `plugins/repo/.claude-plugin/plugin.json`, `plugins/repo/CHANGELOG.md`

- [ ] **Step 1: Failing check**

Run: `bash -c 'git grep -n "Do not commit" -- plugins/repo/skills; for p in "chore/adopt-lyngon-conventions" "git symbolic-ref HEAD refs/heads/main"; do grep -qF "$p" plugins/repo/skills/init/SKILL.md || echo "missing: $p"; done; true'`
Expected: two `Do not commit` lines (init line 118, add-package line 114), then two `missing:` lines.

- [ ] **Step 2: Prove the branch-naming command both ways**

Run: `bash -c 'd=$(mktemp -d); cd "$d"; git init -q -b master; git symbolic-ref HEAD refs/heads/main; echo x >f; git add f; git -c user.email=c@example.com -c user.name=C commit -q -m "chore: initialize repository"; git branch --show-current'`
Expected: `main`.
Control, without the `git symbolic-ref` command: `bash -c 'd=$(mktemp -d); cd "$d"; git init -q -b master; echo x >f; git add f; git -c user.email=c@example.com -c user.name=C commit -q -m "chore: initialize repository"; git branch --show-current'`
Expected: `master`.

- [ ] **Step 3: `init`**

In `plugins/repo/skills/init/SKILL.md`, after the line `### 5. Write` and its blank line, insert:

```markdown
In adopt mode, when the repository is on its default branch, create the branch first: `git switch -c chore/adopt-lyngon-conventions`.
```

followed by a blank line.

Replace the whole `### 7. Hand-off` section with:

````markdown
### 7. Commit and hand off

In fresh mode the repository has no commits, so there is no base for a pull request: everything lands in one root commit on `main`.

```sh
git symbolic-ref HEAD refs/heads/main
git add -A
git commit -m "chore: initialize repository"
```

The first command names the unborn branch `main` when git's default named it otherwise.
Ask before pushing: the commit is on the default branch.

In adopt mode the work is on `chore/adopt-lyngon-conventions`.
Commit by concern, in an order in which each commit passes the hooks, and put two concerns in one commit when neither passes alone:

1. `docs: adopt the Lyngon documents`: `INTENT.md`, `CLAUDE.md` with `AGENTS.md`, `README.md`, `CONCEPTS.md`, the ADRs, `docs/`, `.gitignore` and `.claude/settings.json`.
2. `build: import the Lyngon baseline`: the devenv files and the linter configurations.
3. `ci: run the full check in CI`.
4. `build: adopt the Lyngon structure`: the root workspace files and `secretspec.toml`; then one `feat(<name>): add <kind> <name>` per package.

Then finish the branch with `/build:finish` when the build plugin is installed; otherwise push it and open a pull request.

`add-package` does not commit when this skill invokes it; the commits above include its packages.

Print the next steps for the owner:

1. `devenv allow` in the repository.
2. Either `direnv allow`, or `eval "$(devenv hook zsh)"` (or the equivalent for their shell) in their shell configuration.
3. Install the VS Code extension `mkhl.direnv` so the Claude Code extension sees the devenv tools.
4. In fresh mode without a remote: add one and push `main`.
````

- [ ] **Step 4: `add-package`**

Replace the whole `### 7. Hand-off` section of `plugins/repo/skills/add-package/SKILL.md` with:

```markdown
### 7. Commit

Commit the package as one commit, `feat(<name>): add <kind> <name>`, on the current feature branch; on the default branch, create one first (`git switch -c feat/<name>`).
Do not push: a package is usually one step of larger work, and the push comes when that work is done.
When `repo:init` invoked this skill, skip the commit; init commits the packages itself.
List the files written and the registrations made.
When the package is an app that will be deployed, say that `infra/modules/<name>/` is the next package to add once the deployment target is known.
```

- [ ] **Step 5: Version and changelog**

`repo` 0.7.0 to 0.8.0; add at the top of `plugins/repo/CHANGELOG.md`:

```markdown
## 0.8.0 - 2026-09-29

- `init` commits its work: one root commit on `main` in fresh mode, asking before the push, and in adopt mode commits by concern on `chore/adopt-lyngon-conventions`, then a pull request. `add-package` commits its package on the feature branch and never pushes; under `init` it leaves the commit to `init`.
```

- [ ] **Step 6: Passing check**

Run the Step 1 command again.
Expected: no output.

- [ ] **Step 7: Run the hooks and commit**

Run: `prek run --files plugins/repo/skills/init/SKILL.md plugins/repo/skills/add-package/SKILL.md plugins/repo/.claude-plugin/plugin.json plugins/repo/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/repo
git commit -m "feat(repo): commit the work of init and add-package"
```

### Task 8: `add-skill` commits its result

**Files:**

- Modify: `plugins/devkit/skills/add-skill/SKILL.md:82,104`, `plugins/devkit/skills/add-skill/references/install.md:29`, `plugins/devkit/skills/add-skill/references/create.md:45`
- Modify: `plugins/devkit/.claude-plugin/plugin.json`, `plugins/devkit/CHANGELOG.md`

- [ ] **Step 1: Failing check**

Run: `git grep -n "Do not commit" -- plugins/devkit`
Expected: four lines: `SKILL.md` 82 and 104, `install.md` 29, `create.md` 45.

- [ ] **Step 2: Edit the four places**

| File | Replace | With |
| --- | --- | --- |
| `SKILL.md`, A.6 | `Do not commit; end by offering a Conventional Commits message.` | `Commit the result as one commit on the feature branch (on the default branch, create one first), with the message from [references/install.md](references/install.md); do not push.` |
| `SKILL.md`, B.3 | `Do not commit; end by offering a Conventional Commits message.` | `Commit the result as one commit on the feature branch (on the default branch, create one first), with the message from the reference you followed; do not push.` |
| `references/install.md` | ``- Do not commit. Offer `feat(<concern>): add <name> skill` or `feat(catalog): pin <name>`.`` | ``- Commit as one commit on the feature branch, `feat(<concern>): add <name> skill` or `feat(catalog): pin <name>`; do not push.`` |
| `references/create.md` | ``- Do not commit; offer `feat(<concern>): add <name> skill`.`` | ``- Commit as one commit on the feature branch, `feat(<concern>): add <name> skill`; do not push.`` |

- [ ] **Step 3: Version and changelog**

`devkit` 0.1.4 to 0.2.0; add at the top of `plugins/devkit/CHANGELOG.md`:

```markdown
## 0.2.0 - 2026-09-29

- `add-skill` commits its result as one commit on the feature branch and never pushes, instead of offering a commit message.
```

- [ ] **Step 4: Passing check**

Run the Step 1 command again.
Expected: no output, exit 1.

- [ ] **Step 5: Run the hooks and commit**

Run: `prek run --files plugins/devkit/skills/add-skill/SKILL.md plugins/devkit/skills/add-skill/references/install.md plugins/devkit/skills/add-skill/references/create.md plugins/devkit/.claude-plugin/plugin.json plugins/devkit/CHANGELOG.md`
Expected: every hook `Passed` or `Skipped`.

```bash
git add plugins/devkit
git commit -m "feat(devkit): commit the result of add-skill"
```

### Task 9: This repository's rules for versions and seed prompts

Two commits, one per concern.

**Files:**

- Modify: `CLAUDE.md:39,46`
- Modify: `docs/seed-prompts/session-environment-hooks.md`, `docs/TODO.md`

- [ ] **Step 1: Failing check for the version rule**

Run: `bash -c 'grep -c "Bump it and add a" CLAUDE.md; grep -c "by the commit" CLAUDE.md'`
Expected: `1`, then `0`.

- [ ] **Step 2: The version rule**

Replace `CLAUDE.md` line 46:

```markdown
- Plugin `version` lives in `plugin.json` only. Bump it and add a `CHANGELOG.md` entry with every user-visible change.
```

with

```markdown
- Plugin `version` lives in `plugin.json` only. Every commit with a user-visible change to a plugin bumps that plugin's version by the commit's own semver level and adds its own `CHANGELOG.md` entry, in the same commit.
```

Run the Step 1 command again. Expected: `0`, then `1`.

- [ ] **Step 3: Commit the version rule**

Run: `prek run --files CLAUDE.md`. Expected: every hook `Passed` or `Skipped`.

```bash
git add CLAUDE.md
git commit -m "docs: bump a plugin's version in every commit that changes it"
```

- [ ] **Step 4: Failing check for the seed-prompt lines**

Run: `bash -c 'grep -c "names the branch" CLAUDE.md; grep -c "until I have reviewed" docs/seed-prompts/session-environment-hooks.md; grep -c "Remove this file and its" docs/seed-prompts/session-environment-hooks.md; grep -c "Rethink the process for deferred items" docs/TODO.md'`
Expected: `0`, `1`, `0`, `0`.

- [ ] **Step 5: The seed-prompt lines**

Replace `CLAUDE.md` line 39:

```markdown
- `docs/seed-prompts/<slug>.md`: a self-contained prompt that starts a fresh session on one queued item of `docs/TODO.md`; removed with the entry when the work lands.
```

with

```markdown
- `docs/seed-prompts/<slug>.md`: a self-contained prompt that starts a fresh session on one queued item of `docs/TODO.md`; removed with the entry when the work lands.
  It says how to start (the skill to invoke, or "a bounded change: no design file and no plan file"), names the branch, and ends with "Remove this file and its `docs/TODO.md` entry in the last commit".
  Commits, the full check and the pull request follow the conventions and are not repeated in it.
```

In `docs/seed-prompts/session-environment-hooks.md`, delete the line `Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form.` and add at the end of the file, after a blank line:

```markdown
Remove this file and its `docs/TODO.md` entry in the last commit.
```

In `docs/TODO.md`, add as the first item under `## Deferred`:

```markdown
- 2026-09-29: Rethink the process for deferred items: possibly a skill that writes a `docs/TODO.md` entry and, for a queued item, its seed prompt with the standard lines from `CLAUDE.md`.
```

Run the Step 4 command again. Expected: `1`, `0`, `1`, `1`.

- [ ] **Step 6: Commit the seed-prompt lines**

Run: `prek run --files CLAUDE.md docs/seed-prompts/session-environment-hooks.md docs/TODO.md`. Expected: every hook `Passed` or `Skipped`.

```bash
git add CLAUDE.md docs/seed-prompts/session-environment-hooks.md docs/TODO.md
git commit -m "docs: name the standard lines of a seed prompt"
```

### Task 10: Verify the branch

No commit.

- [ ] **Step 1: The old habit is gone**

Run:

```sh
git grep -n -E 'Do not commit|do not stage|integration menu|Which option\?|until I have reviewed|commit when told|the finished branch|presents the options|before merg' -- plugins shared docs/adr README.md CLAUDE.md docs/seed-prompts ':!*CHANGELOG.md' ':!*UPSTREAM.md' ':!docs/seed-prompts/review-on-the-pull-request.md' ':!docs/seed-prompts/conclude-skill.md'
```

Expected: no output, exit 1.
The same command listed 32 lines on `main` before this work (see the Design's Testing section); that run is the control.

- [ ] **Step 2: The full check**

Run: `devenv test`
Expected: exit 0; every task name reported with its time and no hook failure.

- [ ] **Step 3: Headless check, with the plugins**

Run `bash tmp/headless-check.sh with markdown` three times and `bash tmp/headless-check.sh with python` three times.
Expected: every run meets its row of the pass table.
Append each run's output to `tmp/headless-results.txt`.

- [ ] **Step 4: Headless check, without the plugins (Review Focus 5)**

Run `bash tmp/headless-check.sh without markdown` three times and `bash tmp/headless-check.sh without python` once.
Expected: every run meets the `without` row.
Append each run's output to `tmp/headless-results.txt`.

- [ ] **Step 5: Report**

Report the outputs of Steps 1 to 4.
`tmp/headless-results.txt` goes into the pull request description under Verification.

### Handoff to `build:finish`

The plan-removal commit also removes `docs/seed-prompts/review-on-the-pull-request.md` and its Queued entry in `docs/TODO.md`, as that seed prompt asks: `git rm` both changes and stage them with the plan removal.
`build:finish` is loaded from this checkout, so after Task 4 it already pushes and opens the pull request without asking.
