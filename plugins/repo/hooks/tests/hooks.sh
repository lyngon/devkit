#!/usr/bin/env bash
# Exercise the repo plugin's hook scripts against throwaway projects: the
# environment export with stub devenv and direnv commands, and the session
# start lines with real git repositories. Run through `devenv test`.
set -euo pipefail

hooks=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0

# --- Fixture helpers ---------------------------------------------------------

# Only these tools are on PATH when a hook runs, so a test decides whether
# devenv and direnv exist.
tools=$tmp/tools
mkdir -p "$tools"
for tool in bash cat dirname env find git grep mkdir mktemp mv rm sed sleep sort stat timeout; do
  ln -s "$(command -v "$tool")" "$tools/$tool"
done

# A script shaped like `devenv direnv-export`: assignments, exports, a
# function, a PATH merge and a shell hook that prints.
devenv_script=$tmp/direnv-export.sh
cat >"$devenv_script" <<'EOF'
PATH=${PATH:-}
nix_saved_PATH="$PATH"
DEVENV_PROFILE='/nix/store/0000-devenv-profile'
export DEVENV_PROFILE
TRICKY=$'it\'s "quoted"\nsecond line with $dollar and `tick`'
export TRICKY
UNEXPORTED='stays in the script'
stdenvFunction ()
{
    echo "stdenv function ran"
}
PATH='/nix/store/0000-devenv-profile/bin'
export PATH
PATH="$PATH${nix_saved_PATH:+:$nix_saved_PATH}"
shellHook='echo "shell hook ran"; cd /; cd /'
eval "${shellHook:-}"
EOF

stubs_devenv=$tmp/stubs-devenv
stubs_direnv=$tmp/stubs-direnv
mkdir -p "$stubs_devenv" "$stubs_direnv"
cat >"$stubs_devenv/devenv" <<'EOF'
#!/usr/bin/env bash
# Stub: `devenv direnv-export` prints the fixture script and the DEVENV_ROOT
# of the directory it runs in, or fails. Each run adds a line to
# STUB_DEVENV_LOG.
[[ "$*" == direnv-export && "${_DEVENV_CALLER-}" == direnv ]] || exit 2
echo "• Running devenv:enterShell" >&2
[[ -z "${STUB_DEVENV_LOG-}" ]] || echo "$PWD" >>"$STUB_DEVENV_LOG"
[[ -z "${STUB_DEVENV_FAIL-}" ]] || exit 1
cat "$STUB_DEVENV_SCRIPT"
printf 'DEVENV_ROOT=%q\nexport DEVENV_ROOT\n' "$PWD"
EOF
cat >"$stubs_direnv/direnv" <<'EOF'
#!/usr/bin/env bash
# Stub: `direnv status` reports STUB_DIRENV_ALLOWED for the .envrc here;
# `direnv export bash` prints nothing while inherited state claims the
# environment is loaded, as the real one does.
case "$*" in
  status)
    [[ -f .envrc ]] && echo "Found RC allowed ${STUB_DIRENV_ALLOWED:-0}"
    ;;
  "export bash")
    [[ -n "${DIRENV_DIFF-}" ]] || echo "export FROM_DIRENV=\$'yes';${STUB_DIRENV_IDENTITY:+export LYNGON_AGENT_IDENTITY=\$'$STUB_DIRENV_IDENTITY';}"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$stubs_devenv/devenv" "$stubs_direnv/direnv"

stub_identity=$tmp/stub-identity
cat >"$stub_identity" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "session --root" && -d "$3" ]] || exit 2
if [[ -n "${STUB_IDENTITY_FAIL-}" ]]; then
  echo "Traceback: boom" >&2
  exit 1
fi
echo "export GIT_AUTHOR_NAME='app[bot]'"
echo "export GH_TOKEN=\"\$(echo minted)\""
printf 'Agent identity: agents act as "app[bot]".\nThe second line.\n' >&2
EOF
chmod +x "$stub_identity"
identity_script=$tmp/direnv-export-identity.sh
{
  cat "$devenv_script"
  echo "LYNGON_AGENT_IDENTITY='$stub_identity'"
  echo "export LYNGON_AGENT_IDENTITY"
} >"$identity_script"

# A git working tree with devenv.nix, .envrc and an input list naming a
# package file, a file outside the project and devenv's own state.
new_project() {
  local project
  project=$(mktemp -d "$tmp/project.XXXXXX")
  project=$(cd "$project" && pwd -P)
  mkdir -p "$project/.git" "$project/.devenv" "$project/apps/demo"
  touch "$project/devenv.nix" "$project/.envrc" "$project/apps/demo/devenv.nix"
  printf '%s\n' "$project/apps/demo/devenv.nix" "$project/devenv.nix" /elsewhere/devenv.nix "$project/.devenv/bootstrap/default.nix" >"$project/.devenv/input-paths.txt"
  echo "$project"
}

# new_worktree <project> <name>: a linked worktree of <project> where
# EnterWorktree puts one, with the same devenv files.
new_worktree() {
  local worktree=$1/.claude/worktrees/$2
  mkdir -p "$worktree/.devenv"
  echo "gitdir: $1/.git/worktrees/$2" >"$worktree/.git"
  touch "$worktree/devenv.nix" "$worktree/.envrc"
  echo "$worktree"
}

# run_hook <dir> <project> <event>[:<source>] [VAR=value]...: run the export
# hook in <dir> as Claude Code does in a session launched in <project>, with
# devenv but not direnv on PATH and inherited direnv state: CLAUDE_PROJECT_DIR
# stays at <project>, CLAUDE_ENV_FILE is set at SessionStart only, and the
# input names the session and the source of a SessionStart. Each run of the
# stub devenv adds a line to $project.evaluations. Sets out, err, code.
run_hook() {
  local dir=$1 project=$2 event=${3%%:*} source=${3#*:}
  shift 3
  local env_file=()
  [[ $event != SessionStart ]] || env_file=(CLAUDE_ENV_FILE="$project/env-file.sh")
  code=0
  out=$(cd "$dir" && env -i PATH="$stubs_devenv:$tools" HOME="$tmp" _=/usr/bin/env DIRENV_DIFF=inherited DIRENV_WATCHES=inherited \
    CLAUDE_PROJECT_DIR="$project" "${env_file[@]}" CLAUDE_PLUGIN_DATA="$tmp/plugin-data" \
    STUB_DEVENV_SCRIPT="$devenv_script" STUB_DEVENV_LOG="$project.evaluations" "$@" \
    "$hooks/export-environment.sh" "$event" 2>"$tmp/stderr" \
    <<<"{\"session_id\":\"session-${project##*.}\",\"hook_event_name\":\"$event\",\"source\":\"$source\"}") || code=$?
  err=$(<"$tmp/stderr")
}

# evaluations <project>: how often the stub devenv ran for the session
# launched in <project>.
evaluations() {
  if [[ -f $1.evaluations ]]; then wc -l <"$1.evaluations"; else echo 0; fi
}

# command_runs <dir> <project> <script>: the output of <script> as a Bash
# command that starts in <dir>, in the session launched in <project>: bash,
# with nothing in its environment, runs the session's environment file first.
command_runs() {
  # shellcheck disable=SC2016  # the inner shell expands $1
  (cd "$1" && env -i "$tools/bash" --norc --noprofile -c 'source "$1" >/dev/null 2>&1; '"$3" bash "$2/env-file.sh")
}

# command_sees <dir> <project> <name>: the value of variable <name> in such a
# command, or "unset".
command_sees() {
  command_runs "$1" "$2" "printf '%s' \"\${$3-unset}\""
}

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

# --- export-environment.sh ---------------------------------------------------

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup PATH="$stubs_direnv:$stubs_devenv:$tools"
check "direnv path: a command gets direnv's export, with the inherited direnv state cleared" \
  equals "$(command_sees "$project" "$project" FROM_DIRENV)" "yes"
check "direnv path: exits 0, prints nothing and says how it exported" \
  equals "$code|$out|$err" "0||repo plugin: exported the devenv environment of $project through direnv"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup PATH="$stubs_direnv:$stubs_devenv:$tools" STUB_DIRENV_ALLOWED=1
check "direnv not allowed: falls back to devenv and says why" \
  equals "$(command_sees "$project" "$project" DEVENV_PROFILE)|$err" "/nix/store/0000-devenv-profile|repo plugin: exported the devenv environment of $project through devenv, because direnv has not allowed .envrc"

project=$(new_project)
rm "$project/.envrc"
run_hook "$project" "$project" SessionStart:startup PATH="$stubs_direnv:$stubs_devenv:$tools"
check "no .envrc: exports through devenv and says why" \
  equals "$(command_sees "$project" "$project" DEVENV_PROFILE)|$err" "/nix/store/0000-devenv-profile|repo plugin: exported the devenv environment of $project through devenv, because the project has no .envrc"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup
check "no direnv: exits 0, prints nothing and says why it used devenv" \
  equals "$code|$out|$err" "0||repo plugin: exported the devenv environment of $project through devenv, because direnv is not on PATH"
check "devenv path: a command gets exactly the exported variables the devenv script added or changed" \
  equals "$(comm -13 <(cd "$project" && env -i "$tools/bash" --norc --noprofile -c 'compgen -e' | sort) <(command_runs "$project" "$project" 'compgen -e' | sort) | tr '\n' ' ')" \
  "DEVENV_PROFILE DEVENV_ROOT PATH TRICKY "
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: sourcing the environment file in bash prints nothing and leaves no function or variable of its own" \
  equals "$(cd "$project" && env -i "$tools/bash" --norc --noprofile -c 'source "$1" || echo "source failed"; type stdenvFunction >/dev/null 2>&1 && echo defined; [[ -v lyngon_tree ]] && echo lyngon_tree; true' bash "$project/env-file.sh" 2>&1)" ""
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: bash reads every value back exactly" \
  equals "$(command_runs "$project" "$project" 'printf "%s|%s|%s" "$DEVENV_PROFILE" "$TRICKY" "$PATH"')" \
  "/nix/store/0000-devenv-profile|it's \"quoted\""$'\n'"second line with \$dollar and \`tick\`|/nix/store/0000-devenv-profile/bin:$stubs_devenv:$tools"
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: zsh, the other shell of Bash commands, reads every value back exactly" \
  equals "$(cd "$project" && env -i "$(command -v zsh)" -f -c 'source "$1"; print -rn -- "$TRICKY|$DEVENV_PROFILE|${lyngon_tree-unset}"' zsh "$project/env-file.sh")" \
  "it's \"quoted\""$'\n'"second line with \$dollar and \`tick\`|/nix/store/0000-devenv-profile|unset"

# Issue 154: Claude Code keeps CLAUDE_PROJECT_DIR at the launch tree, and runs
# no SessionStart, CwdChanged or FileChanged hook when a session enters or
# leaves a worktree, or when a resumed session moves back into one.
project=$(new_project)
worktree=$(new_worktree "$project" moved)
run_hook "$project" "$project" SessionStart:startup
run_hook "$worktree" "$project" PreToolUse
in_worktree=$(command_sees "$worktree" "$project" DEVENV_ROOT)
run_hook "$project" "$project" PreToolUse
in_project=$(command_sees "$project" "$project" DEVENV_ROOT)
run_hook "$project" "$project" SessionStart:resume
run_hook "$worktree" "$project" PreToolUse
check "a move into a worktree, back out, and a resume into it: each command gets the devenv environment of its own tree" \
  equals "$in_worktree|$in_project|$(command_sees "$worktree" "$project" DEVENV_ROOT)" "$worktree|$project|$worktree"

project=$(new_project)
mkdir -p "$project/tmp/scratch/.git"
run_hook "$project" "$project" SessionStart:startup
run_hook "$project/tmp/scratch" "$project" PreToolUse
check "a package directory and a repository without devenv.nix inside the tree get the tree's environment, outside every tree none" \
  equals "$(command_sees "$project/apps/demo" "$project" DEVENV_ROOT)|$(command_sees "$project/tmp/scratch" "$project" DEVENV_ROOT)|$(command_sees "$tmp" "$project" DEVENV_ROOT)|$(evaluations "$project")" \
  "$project|$project|unset|1"

project=$(new_project)
worktree=$(new_worktree "$project" kept)
run_hook "$project" "$project" SessionStart:startup
run_hook "$worktree" "$project" PreToolUse
run_hook "$project" "$project" SessionStart:compact
run_hook "$worktree" "$project" PreToolUse
check "a compaction keeps the worktree's environment: no second evaluation of it" \
  equals "$(grep -c -x "$worktree" "$project.evaluations")" "1"
run_hook "$project" "$project" SessionStart:resume PATH="$stubs_devenv:$tools:/resumed"
run_hook "$worktree" "$project" PreToolUse PATH="$stubs_devenv:$tools:/resumed"
check "a resume evaluates the worktree again, on top of the environment of the new process" \
  equals "$(grep -c -x "$worktree" "$project.evaluations")|$(command_sees "$worktree" "$project" PATH)" \
  "2|/nix/store/0000-devenv-profile/bin:$stubs_devenv:$tools:/resumed"

project=$(new_project)
worktree=$(new_worktree "$project" later)
rm "$project/devenv.nix"
run_hook "$project" "$project" SessionStart:startup
run_hook "$worktree" "$project" PreToolUse
check "a session launched in a tree without devenv.nix: a worktree with one still gets its environment" \
  equals "$(command_sees "$worktree" "$project" DEVENV_ROOT)" "$worktree"

project=$(new_project)
script=$(mktemp "$tmp/script.XXXXXX")
cp "$devenv_script" "$script"
run_hook "$project" "$project" SessionStart:startup STUB_DEVENV_SCRIPT="$script"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
mkdir -p "$project/.devenv/bootstrap"
touch "$project/.devenv/bootstrap/default.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
check "nothing the evaluation reads changed, devenv's own state aside: PreToolUse evaluates nothing and prints nothing" \
  equals "$(evaluations "$project")|$code|$out|$err" "1|0||"
echo "TRICKY=changed; export TRICKY" >>"$script"
touch "$project/apps/demo/devenv.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
check "a package devenv.nix that the last evaluation read changed: the next command gets the new environment" \
  equals "$(evaluations "$project")|$(command_sees "$project" "$project" TRICKY)" "2|changed"
grep -v TRICKY "$devenv_script" >"$script"
touch "$project/devenv.local.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
check "a root devenv file added: the next command gets the new environment, without a variable the evaluation dropped" \
  equals "$(evaluations "$project")|$(command_sees "$project" "$project" TRICKY)" "3|unset"
rm "$project/devenv.local.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
check "a root devenv file removed: evaluates again" \
  equals "$(evaluations "$project")" "4"

project=$(new_project)
worktree=$(new_worktree "$project" broken)
script=$(mktemp "$tmp/script.XXXXXX")
cp "$devenv_script" "$script"
run_hook "$project" "$project" SessionStart:startup
touch "$project/devenv.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_FAIL=1
check "failed evaluation: commands keep the tree's previous environment" \
  equals "$(command_sees "$project" "$project" DEVENV_ROOT)" "$project"
check "failed evaluation: exits 0, says so, and tells the session" \
  equals "$code|$out|$err" "0|{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"The devenv evaluation of $project failed, so Bash commands there keep its previous devenv environment until a devenv file changes. Run devenv shell there to see why.\"}}|repo plugin: kept the previous devenv environment of $project, because the evaluation failed; run devenv shell there to see why"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_FAIL=1
check "failed evaluation: no second try and no second message until a devenv file changes" \
  equals "$(evaluations "$project")|$out" "2|"
echo "TRICKY=fixed; export TRICKY" >>"$script"
touch "$project/devenv.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$script"
check "failed evaluation: a fix reaches the next command" \
  equals "$(evaluations "$project")|$(command_sees "$project" "$project" TRICKY)" "3|fixed"
run_hook "$worktree" "$project" PreToolUse STUB_DEVENV_FAIL=1
check "failed first evaluation of a tree: commands there run without a devenv environment, not the launch tree's, and the session is told" \
  equals "$(command_sees "$worktree" "$project" DEVENV_ROOT)|$out" \
  "unset|{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"The devenv evaluation of $worktree failed, so Bash commands there run without its devenv environment until a devenv file changes. Run devenv shell there to see why.\"}}"

# devenv records the files it read under the physical path of the project.
project=$(new_project)
ln -s "$project" "$tmp/linked"
run_hook "$tmp/linked" "$project" SessionStart:startup
touch "$project/apps/demo/devenv.nix"
run_hook "$tmp/linked" "$project" PreToolUse
check "project reached through a symbolic link: a command there gets its environment, and a package change still counts" \
  equals "$(command_sees "$tmp/linked" "$project" DEVENV_ROOT)|$(evaluations "$project")" "$project|2"

project=$(new_project)
rm "$project/devenv.nix"
run_hook "$project" "$project" SessionStart:startup
check "no devenv.nix: a command gets no devenv environment, and session start prints nothing and says why" \
  equals "$(command_sees "$project" "$project" DEVENV_ROOT)|$code|$out|$err" \
  "unset|0||repo plugin: no devenv environment to export, because no git working tree with a devenv.nix holds $project"

project=$(new_project)
rm -r "$project/.git"
run_hook "$project" "$project" SessionStart:startup
check "a devenv.nix outside every git working tree: no devenv environment, and session start says why" \
  equals "$(command_sees "$project" "$project" DEVENV_ROOT)|$err" \
  "unset|repo plugin: no devenv environment to export, because no git working tree with a devenv.nix holds $project"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup PATH="$stubs_direnv:$tools"
check "no devenv on PATH: a command gets no devenv environment, and session start says why" \
  equals "$(command_sees "$project" "$project" DEVENV_ROOT)|$code|$out|$err" "unset|0||repo plugin: no devenv environment to export, because devenv is not on PATH"
run_hook "$project" "$project" PreToolUse PATH="$stubs_direnv:$tools"
check "no devenv on PATH: PreToolUse, which runs before every command, says nothing" \
  equals "$code|$out|$err" "0||"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup CLAUDE_ENV_FILE=
check "no CLAUDE_ENV_FILE: writes nothing, exits 0 and says why" \
  equals "$(ls "$project/env-file.sh" 2>/dev/null)$out|$code: $err" "|0: repo plugin: no devenv environment to export, because CLAUDE_ENV_FILE is not set"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup CLAUDE_PLUGIN_DATA=
check "no CLAUDE_PLUGIN_DATA: writes nothing, exits 0 and says why" \
  equals "$(ls "$project/env-file.sh" 2>/dev/null)$out|$code: $err" "|0: repo plugin: no devenv environment to export, because CLAUDE_PLUGIN_DATA is not set"

identity_message='"Agent identity: agents act as \"app[bot]\".\nThe second line."'

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup STUB_DEVENV_SCRIPT="$identity_script"
# shellcheck disable=SC2016  # the expected line holds the command substitution unexpanded
check "agent identity: the environment file ends with the lines of agent-identity" \
  equals "$(tail -n 2 "$project/env-file.sh")" "export GIT_AUTHOR_NAME='app[bot]'"$'\n''export GH_TOKEN="$(echo minted)"'
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "agent identity: a command runs the token line" \
  equals "$(command_runs "$project" "$project" 'printf "%s|%s" "$GH_TOKEN" "$GIT_AUTHOR_NAME"')" "minted|app[bot]"
check "agent identity: its message is the session's context, as one JSON string" \
  equals "$out" "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":$identity_message}}"
touch "$project/devenv.nix"
run_hook "$project" "$project" PreToolUse STUB_DEVENV_SCRIPT="$identity_script"
check "agent identity on a later evaluation: no message, and commands keep the identity of the session start" \
  equals "$(evaluations "$project")|$out|$(command_sees "$project" "$project" GH_TOKEN)" "2||minted"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup PATH="$stubs_direnv:$stubs_devenv:$tools" STUB_DIRENV_IDENTITY="$stub_identity"
# shellcheck disable=SC2016  # the expected line holds the command substitution unexpanded
check "agent identity through direnv: the same lines and message" \
  equals "$(tail -n 1 "$project/env-file.sh")|$(grep -c additionalContext <<<"$out")" 'export GH_TOKEN="$(echo minted)"|1'

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup STUB_DEVENV_SCRIPT="$identity_script" STUB_IDENTITY_FAIL=1
check "agent identity fails: GitHub is closed to the session" \
  equals "$(tail -n 1 "$project/env-file.sh")" "export GH_TOKEN='agent-identity-failed'"
check "agent identity fails: the context names the command and what it printed" \
  grep -qF "\"additionalContext\":\"Agent identity: agents cannot reach GitHub in this session, because $stub_identity failed: Traceback: boom\"" <<<"$out"

project=$(new_project)
run_hook "$project" "$project" SessionStart:startup STUB_DEVENV_SCRIPT="$identity_script" STUB_DEVENV_FAIL=1
check "failed evaluation at session start: the context says agents act as the operator" \
  grep -qF '"additionalContext":"Agent identity: agents act on GitHub as you, the operator, because the devenv evaluation failed' <<<"$out"

# --- session-start.sh --------------------------------------------------------

commit() {
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -q --allow-empty -m "$2"
}

upstream_clone() {
  local behind=$1 dir i
  dir=$(mktemp -d "$tmp/git.XXXXXX")
  git init -q --bare -b main "$dir/origin.git"
  git init -q -b main "$dir/other"
  git -C "$dir/other" remote add origin "$dir/origin.git"
  commit "$dir/other" base
  git -C "$dir/other" push -q origin main
  git clone -q "$dir/origin.git" "$dir/clone"
  for ((i = 1; i <= behind; i++)); do
    commit "$dir/other" "upstream $i"
    git -C "$dir/other" push -q origin main
  done
  echo "$dir/clone"
}

squash_merge_on_origin() {
  local clone=$1 branch=$2 github
  github=$(mktemp -d "$tmp/github.XXXXXX")
  git clone -q "$(git -C "$clone" remote get-url origin)" "$github"
  git -C "$github" merge -q --squash "origin/$branch" >/dev/null
  commit "$github" "squash of $branch"
  git -C "$github" push -q origin main
  git -C "$github" push -q origin --delete "$branch"
}

run_session_start() {
  code=0
  out=$(env -i PATH="$tools" HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 CLAUDE_PROJECT_DIR="$1" "$hooks/session-start.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

run_session_start "$(upstream_clone 2)"
check "two commits behind since the last fetch: the hook fetches, and one line says so, with the command" \
  equals "$code|$out|$err" "0|The current branch is 2 commits behind its upstream; fast-forward before starting: \`git pull --ff-only\`.|"

run_session_start "$(upstream_clone 1)"
check "one commit behind: the singular" \
  equals "$out" "The current branch is 1 commit behind its upstream; fast-forward before starting: \`git pull --ff-only\`."

clone=$(upstream_clone 0)
commit "$clone" ahead
run_session_start "$clone"
check "up to date or ahead: nothing" equals "$code|$out|$err" "0||"

clone=$(upstream_clone 2)
git -C "$clone" switch -q -c feat/next
run_session_start "$clone"
check "main behind origin/main, on a feature branch: one line saying so, with the branch to start from" \
  equals "$code|$out|$err" "0|The local main is 2 commits behind origin/main. Start every new branch from origin/main, not from main.|"

clone=$(upstream_clone 0)
git -C "$clone" switch -q -c feat/merged
commit "$clone" work
git -C "$clone" push -q -u origin feat/merged
squash_merge_on_origin "$clone" feat/merged
run_session_start "$clone"
check "on a branch whose upstream was deleted at its merge: says so, and that main is behind" \
  equals "$code|$out|$err" "0|The current branch, feat/merged, tracks origin/feat/merged, which no longer exists, as when a pull request merges and GitHub deletes its branch. Before you work on feat/merged again, check whether its pull request merged. Start new work on a new branch from origin/main."$'\n'"The local main is 1 commit behind origin/main. Start every new branch from origin/main, not from main.|"

clone=$(upstream_clone 2)
git -C "$clone" fetch -q
git -C "$clone" switch -q -c feat/next
git -C "$clone" config remote.origin.uploadpack 'sleep 60; git-upload-pack'
start=$EPOCHREALTIME
run_session_start "$clone"
seconds=$(((${EPOCHREALTIME/./} - ${start/./}) / 1000000))
timeout=$(jq '.hooks.SessionStart[].hooks[] | select(.command | endswith("/hooks/session-start.sh")) | .timeout' "$hooks/hooks.json")
check "origin never answers: says it could not fetch, then what the last fetch saw" \
  equals "$code|$out|$err" "0|Could not fetch origin at session start (no answer within 10 s), so what this session knows of origin dates from the last fetch. Before you start a branch, fetch again. If that fetch fails too, say so."$'\n'"The local main is 2 commits behind origin/main. Start every new branch from origin/main, not from main.|"
check "origin never answers: the hook ends in $seconds s, before its timeout of $timeout s in hooks.json" \
  test "$seconds" -lt "$timeout"

clone=$(upstream_clone 0)
git -C "$clone" remote set-url origin "$tmp/missing.git"
run_session_start "$clone"
check "origin unreachable: says it could not fetch, with git's reason" \
  equals "$code|$out|$err" "0|Could not fetch origin at session start (fatal: '$tmp/missing.git' does not appear to be a git repository), so what this session knows of origin dates from the last fetch. Before you start a branch, fetch again. If that fetch fails too, say so.|"

dir=$(mktemp -d "$tmp/git.XXXXXX")
git init -q -b main "$dir"
commit "$dir" only
run_session_start "$dir"
check "no upstream: nothing" equals "$code|$out|$err" "0||"

run_session_start "$(mktemp -d "$tmp/plain.XXXXXX")"
check "not a git repository: nothing" equals "$code|$out|$err" "0||"

clone=$(upstream_clone 3)
printf '{\n  lyngon.enable = true;\n  lyngon.structure.enable = true;\n}\n' >"$clone/devenv.nix"
run_session_start "$clone"
check "structure marker and behind: the structure text, then the line" \
  equals "$out" "$(cat "$hooks/session-start-structure.txt")"$'\n'"The current branch is 3 commits behind its upstream; fast-forward before starting: \`git pull --ff-only\`."

dir=$(mktemp -d "$tmp/plain.XXXXXX")
echo "This repository follows the Lyngon structure. Packages are laid out by kind." >"$dir/CLAUDE.md"
run_session_start "$dir"
check "the sentence in an agent file is no marker: nothing" equals "$code|$out|$err" "0||"

dir=$(mktemp -d "$tmp/plain.XXXXXX")
printf '{\n  # lyngon.structure.enable = true;\n  lyngon.structure.enable = false;\n}\n' >"$dir/devenv.nix"
run_session_start "$dir"
check "the option commented out or false: nothing" equals "$code|$out|$err" "0||"

if ((failures > 0)); then
  echo "repo hooks tests: $failures failure(s)" >&2
  exit 1
fi
echo "repo hooks tests: ok"
