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
for tool in bash cat dirname env git grep mktemp mv rm sed sort; do
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
# Stub: `devenv direnv-export` prints the fixture script, or fails.
[[ "$*" == direnv-export && "${_DEVENV_CALLER-}" == direnv ]] || exit 2
echo "• Running devenv:enterShell" >&2
[[ -z "${STUB_DEVENV_FAIL-}" ]] || exit 1
cat "$STUB_DEVENV_SCRIPT"
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
    [[ -n "${DIRENV_DIFF-}" ]] || echo "export FROM_DIRENV=\$'yes';"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$stubs_devenv/devenv" "$stubs_direnv/direnv"

# A project with devenv.nix, .envrc and an input list naming a package file,
# a file outside the project and devenv's own state.
new_project() {
  local project
  project=$(mktemp -d "$tmp/project.XXXXXX")
  project=$(cd "$project" && pwd -P)
  mkdir -p "$project/.devenv" "$project/apps/demo"
  touch "$project/devenv.nix" "$project/.envrc" "$project/apps/demo/devenv.nix"
  printf '%s\n' "$project/apps/demo/devenv.nix" "$project/devenv.nix" /elsewhere/devenv.nix "$project/.devenv/bootstrap/default.nix" >"$project/.devenv/input-paths.txt"
  echo "$project"
}

# run_export <project> <path> <event> [VAR=value]...: run the export hook with
# only <path> and the given variables in its environment. Sets out, err, code.
run_export() {
  local project=$1 path=$2 event=$3
  shift 3
  code=0
  out=$(cd "$project" && env -i PATH="$path" HOME="$tmp" _=/usr/bin/env DIRENV_DIFF=inherited DIRENV_WATCHES=inherited \
    CLAUDE_PROJECT_DIR="$project" CLAUDE_ENV_FILE="$project/env-file.sh" STUB_DEVENV_SCRIPT="$devenv_script" \
    "$@" "$hooks/export-environment.sh" "$event" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
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
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" SessionStart
check "direnv path: the environment file holds direnv's export, with the inherited state cleared" \
  equals "$(cat "$project/env-file.sh")" "export FROM_DIRENV=\$'yes';"
check "direnv path: exits 0 and says how it exported" \
  equals "$code: $err" "0: repo plugin: exported the devenv environment through direnv"
check "direnv path: watches the root devenv files and the package files devenv read, nothing else" \
  equals "$out" "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"watchPaths\":[\"$project/.envrc\",\"$project/apps/demo/devenv.nix\",\"$project/devenv.local.nix\",\"$project/devenv.local.yaml\",\"$project/devenv.lock\",\"$project/devenv.nix\",\"$project/devenv.yaml\"]}}"

project=$(new_project)
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" FileChanged STUB_DIRENV_ALLOWED=1
check "direnv not allowed: falls back to devenv" \
  grep -q '^export DEVENV_PROFILE=' "$project/env-file.sh"
check "direnv not allowed: says why it used devenv" \
  equals "$err" "repo plugin: exported the devenv environment through devenv, because direnv has not allowed .envrc"
check "the output names the event that ran the hook" \
  grep -q '"hookEventName":"FileChanged"' <<<"$out"

project=$(new_project)
run_export "$project" "$stubs_devenv:$tools" CwdChanged
fallback=$project/env-file.sh
check "no direnv: says why it used devenv" \
  equals "$err" "repo plugin: exported the devenv environment through devenv, because direnv is not on PATH"
check "devenv path: standard output is the watch list alone, as Claude Code parses it" \
  equals "$(wc -l <<<"$out")${out:0:22}" '1{"hookSpecificOutput":'
check "devenv path: exports exactly the variables the devenv script added or changed" \
  equals "$(sed -n 's/^export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$fallback" | sort | tr '\n' ' ')" "DEVENV_PROFILE PATH TRICKY "
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: sourcing the file in bash prints nothing and defines no function" \
  equals "$(env -i "$tools/bash" --norc --noprofile -c 'source "$1" || echo "source failed"; type stdenvFunction >/dev/null 2>&1 && echo defined; true' bash "$fallback" 2>&1)" ""
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: bash reads every value back exactly" \
  equals "$(env -i "$tools/bash" --norc --noprofile -c 'source "$1"; printf "%s|%s|%s" "$DEVENV_PROFILE" "$TRICKY" "$PATH"' bash "$fallback")" \
  "/nix/store/0000-devenv-profile|it's \"quoted\""$'\n'"second line with \$dollar and \`tick\`|/nix/store/0000-devenv-profile/bin:$stubs_devenv:$tools"
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "devenv path: zsh reads every value back exactly" \
  equals "$(env -i "$(command -v zsh)" -f -c 'source "$1"; print -rn -- "$TRICKY|$DEVENV_PROFILE"' zsh "$fallback")" \
  "it's \"quoted\""$'\n'"second line with \$dollar and \`tick\`|/nix/store/0000-devenv-profile"

project=$(new_project)
rm "$project/.envrc"
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" SessionStart
check "no .envrc: exports through devenv and says why" \
  equals "$(grep -c '^export DEVENV_PROFILE=' "$project/env-file.sh")|$err" "1|repo plugin: exported the devenv environment through devenv, because the project has no .envrc"

# devenv records the files it read under the physical path of the project.
project=$(new_project)
ln -s "$project" "$tmp/linked"
code=0
out=$(cd "$tmp/linked" && env -i PATH="$stubs_devenv:$tools" CLAUDE_PROJECT_DIR="$tmp/linked" CLAUDE_ENV_FILE="$project/env-file.sh" \
  STUB_DEVENV_SCRIPT="$devenv_script" "$hooks/export-environment.sh" SessionStart 2>/dev/null) || code=$?
check "project reached through a symbolic link: still watches the package files" \
  grep -qF "\"$project/apps/demo/devenv.nix\"" <<<"$out"

project=$(new_project)
echo "export PREVIOUS=1" >"$project/env-file.sh"
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" FileChanged STUB_DEVENV_FAIL=1
check "failed evaluation: the previous environment file stays untouched" \
  equals "$(cat "$project/env-file.sh")" "export PREVIOUS=1"
check "failed evaluation: exits 0 and says so" \
  equals "$code: $err" "0: repo plugin: kept the previous devenv environment, because the evaluation failed; run devenv shell to see why"
check "failed evaluation: keeps watching, so a fix triggers a new export" \
  grep -qF "\"$project/devenv.nix\"" <<<"$out"

project=$(new_project)
rm "$project/devenv.nix"
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" SessionStart
check "no devenv.nix: writes nothing and prints no output" \
  equals "$(ls "$project/env-file.sh" 2>/dev/null)$out" ""
check "no devenv.nix: exits 0 and says why" \
  equals "$code: $err" "0: repo plugin: no devenv environment to export, because the project has no devenv.nix"

project=$(new_project)
run_export "$project" "$stubs_direnv:$tools" SessionStart
check "no devenv on PATH: writes nothing, exits 0 and says why" \
  equals "$(ls "$project/env-file.sh" 2>/dev/null)$out|$code: $err" "|0: repo plugin: no devenv environment to export, because devenv is not on PATH"

project=$(new_project)
run_export "$project" "$stubs_direnv:$stubs_devenv:$tools" SessionStart CLAUDE_ENV_FILE=
check "no CLAUDE_ENV_FILE: writes nothing, exits 0 and says why" \
  equals "$(ls "$project/env-file.sh" 2>/dev/null)$out|$code: $err" "|0: repo plugin: no devenv environment to export, because CLAUDE_ENV_FILE is not set"

# --- session-start.sh --------------------------------------------------------

commit() {
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -q --allow-empty -m "$2"
}

# upstream_clone <commits the clone is behind>: a clone whose upstream has
# moved on by that many commits, seen through a fetch.
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
  git -C "$dir/clone" fetch -q
  echo "$dir/clone"
}

run_session_start() {
  code=0
  out=$(env -i PATH="$tools" HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 CLAUDE_PROJECT_DIR="$1" "$hooks/session-start.sh" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

run_session_start "$(upstream_clone 2)"
check "two commits behind: one line saying so, with the command" \
  equals "$code|$out|$err" "0|The current branch is 2 commits behind its upstream; fast-forward before starting: \`git pull --ff-only\`.|"

run_session_start "$(upstream_clone 1)"
check "one commit behind: the singular" \
  equals "$out" "The current branch is 1 commit behind its upstream; fast-forward before starting: \`git pull --ff-only\`."

clone=$(upstream_clone 0)
commit "$clone" ahead
run_session_start "$clone"
check "up to date or ahead: nothing" equals "$code|$out|$err" "0||"

dir=$(mktemp -d "$tmp/git.XXXXXX")
git init -q -b main "$dir"
commit "$dir" only
run_session_start "$dir"
check "no upstream: nothing" equals "$code|$out|$err" "0||"

run_session_start "$(mktemp -d "$tmp/plain.XXXXXX")"
check "not a git repository: nothing" equals "$code|$out|$err" "0||"

clone=$(upstream_clone 3)
echo "This repository follows the Lyngon structure. Packages are laid out by kind." >"$clone/CLAUDE.md"
run_session_start "$clone"
check "structure marker and behind: the structure text, then the line" \
  equals "$out" "$(cat "$hooks/session-start-structure.txt")"$'\n'"The current branch is 3 commits behind its upstream; fast-forward before starting: \`git pull --ff-only\`."

if ((failures > 0)); then
  echo "repo hooks tests: $failures failure(s)" >&2
  exit 1
fi
echo "repo hooks tests: ok"
