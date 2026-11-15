#!/usr/bin/env bash
# Claude Code captures its own environment once, at start, and gives
# $CLAUDE_ENV_FILE, which it runs before every Bash command, only to
# SessionStart, CwdChanged and FileChanged hooks, none of which runs in the
# new tree when a session enters or leaves a worktree or resumes into one,
# while CLAUDE_PROJECT_DIR stays at the launch tree.
set -euo pipefail

event=$1
input=$(cat)

say() {
  echo "repo plugin: $*" >&2
}

json_string() {
  local text=$1
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  printf '"%s"' "$text"
}

skip() {
  [[ $event != SessionStart ]] || say "no devenv environment to export, because $1"
  exit 0
}

context() {
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' "$event" "$(json_string "$1")"
}

replace_atomically() {
  local tmp
  mkdir -p "${1%/*}"
  tmp=$(mktemp "$1.XXXXXX")
  printf '%s\n' "$2" >"$tmp"
  mv "$tmp" "$1"
}

# shellcheck disable=SC2016  # expanded where the lines run
climb_to_tree='while [ -n "$lyngon_tree" ] && ! { [ -e "$lyngon_tree/.git" ] && [ -f "$lyngon_tree/devenv.nix" ]; }; do lyngon_tree=${lyngon_tree%/*}; done'
same_process_sources='"source":"(compact|clear)"'
days_unused_before_removal=7

[[ -n ${CLAUDE_PLUGIN_DATA-} ]] || skip "CLAUDE_PLUGIN_DATA is not set"
[[ $input =~ \"session_id\":\"([A-Za-z0-9_-]+)\" ]] || skip "the hook input names no session"
sessions=$CLAUDE_PLUGIN_DATA/sessions
environments=$sessions/${BASH_REMATCH[1]}

if [[ $event == SessionStart ]]; then
  [[ -n ${CLAUDE_ENV_FILE-} ]] || skip "CLAUDE_ENV_FILE is not set"
  [[ $input =~ $same_process_sources ]] || rm -rf "$environments"
  mkdir -p "$sessions"
  find "$sessions" -mindepth 1 -maxdepth 1 -mtime +"$days_unused_before_removal" -exec rm -rf {} +
  quoted=$(printf %q "$environments")
  # shellcheck disable=SC2016  # expanded where the lines run
  env_lines='lyngon_tree=$(pwd -P 2>/dev/null)'$'\n'$climb_to_tree$'\n'"[ ! -f $quoted\"\$lyngon_tree/environment.sh\" ] || . $quoted\"\$lyngon_tree/environment.sh\""$'\n''unset lyngon_tree'
  replace_atomically "$CLAUDE_ENV_FILE" "$env_lines"
fi

lyngon_tree=$(pwd -P)
eval "$climb_to_tree"
tree=$lyngon_tree
[[ -n $tree ]] || skip "no git working tree with a devenv.nix holds $PWD"
command -v devenv >/dev/null || skip "devenv is not on PATH"
file=$environments$tree/environment.sh
cd "$tree"

watch_paths() {
  local file
  for file in .envrc devenv.nix devenv.yaml devenv.lock devenv.local.nix devenv.local.yaml; do
    echo "$tree/$file"
  done
  [[ -f .devenv/input-paths.txt ]] || return 0
  while IFS= read -r file; do
    case $file in
      "$tree"/.devenv/* | "$tree"/.direnv/*) ;;
      "$tree"/*) echo "$file" ;;
    esac
  done <.devenv/input-paths.txt
}

inputs() {
  local paths
  mapfile -t paths < <(watch_paths | sort -u)
  stat -c '%.9Y %n' -- "${paths[@]}" 2>/dev/null || true
}

recorded() {
  local line
  while IFS= read -r line && [[ $line == "# input "* ]]; do
    echo "${line#"# input "}"
  done <"$file"
}

# Runs a `devenv direnv-export` script in a subshell and prints the exported
# variables it added or changed as export statements, which is what direnv
# keeps of it. Written out as is, the script would run its shell hook and
# define its functions before every command.
import_devenv() {
  (
    set +euo pipefail
    local name
    declare -A before=()
    for name in $(compgen -e); do before[$name]=${!name}; done
    eval "$1" >/dev/null 2>&1
    for name in $(compgen -e); do
      case $name in OLDPWD | PWD) continue ;; esac
      [[ -v before[$name] && ${before[$name]} == "${!name}" ]] && continue
      printf 'export %s=%q\n' "$name" "${!name}"
    done
  )
}

signature=$(inputs)
header="# input ${signature//$'\n'/$'\n'# input }"
if [[ $event == PreToolUse && -f $file && $(recorded) == "$signature" ]]; then
  exit 0
fi

# Inherited direnv state claims the environment is loaded already, so direnv
# would export nothing.
unset "${!DIRENV_@}"

how=direnv
if ! command -v direnv >/dev/null; then
  how="devenv, because direnv is not on PATH"
elif [[ ! -f .envrc ]]; then
  how="devenv, because the project has no .envrc"
elif ! grep -qx 'Found RC allowed 0' <<<"$(direnv status 2>/dev/null)"; then
  how="devenv, because direnv has not allowed .envrc"
fi

# direnv's devenv integration exits 0 when the evaluation fails, so evaluate
# first; direnv then reuses devenv's cached evaluation.
if ! script=$(_DEVENV_CALLER=direnv devenv direnv-export 2>/dev/null) ||
  { [[ $how == direnv ]] && ! env=$(direnv export bash 2>/dev/null); }; then
  previous=""
  [[ ! -f $file ]] || previous=$(sed '/^# input /d' "$file")
  replace_atomically "$file" "$header${previous:+$'\n'$previous}"
  say "kept the previous devenv environment of $tree, because the evaluation failed; run devenv shell there to see why"
  if [[ $event == SessionStart ]]; then
    context "Agent identity: agents act on GitHub as you, the operator, because the devenv evaluation failed, so nothing resolved an identity; a new session does once devenv shell works."
  elif [[ -n $previous ]]; then
    context "The devenv evaluation of $tree failed, so Bash commands there keep its previous devenv environment until a devenv file changes. Run devenv shell there to see why."
  else
    context "The devenv evaluation of $tree failed, so Bash commands there run without its devenv environment until a devenv file changes. Run devenv shell there to see why."
  fi
  exit 0
fi
[[ $how == direnv ]] || env=$(import_devenv "$script")
replace_atomically "$file" "$header"$'\n'"$env"
say "exported the devenv environment of $tree through $how"
[[ $event == SessionStart ]] || exit 0

identity_lines="" message=""
identity=$(
  eval "$env" >/dev/null 2>&1
  printf '%s' "${LYNGON_AGENT_IDENTITY-}"
)
if [[ -n $identity ]]; then
  stderr=$(mktemp)
  if identity_lines=$("$identity" session --root "$tree" 2>"$stderr"); then
    message=$(<"$stderr")
  else
    identity_lines="export GH_TOKEN='agent-identity-failed'"
    message="Agent identity: agents cannot reach GitHub in this session, because $identity failed: $(<"$stderr")"
  fi
  rm -f "$stderr"
fi
replace_atomically "$CLAUDE_ENV_FILE" "$env_lines${identity_lines:+$'\n'$identity_lines}"
[[ -z $message ]] || context "$message"
