#!/usr/bin/env bash
# SessionStart, CwdChanged and FileChanged hook of the repo plugin: writes the
# project's devenv environment to $CLAUDE_ENV_FILE, which Claude Code runs
# before every Bash command, and prints the files to watch, so a change to one
# of them runs this hook again. Claude Code captures its own environment once,
# at start, so without this the tools and variables of devenv.nix are missing
# or stale. The only argument is the hook event. It prints one line on stderr
# and exits 0; a failed evaluation leaves the previous file in place.
set -euo pipefail

event=$1
root=${CLAUDE_PROJECT_DIR:-$PWD}

say() {
  echo "repo plugin: $*" >&2
}

# The root devenv files, and every file under the project that the last
# evaluation read (the package devenv.nix files among them) except devenv's
# own state: what devenv's direnv integration watches.
watch_paths() {
  local file
  for file in .envrc devenv.nix devenv.yaml devenv.lock devenv.local.nix devenv.local.yaml; do
    echo "$root/$file"
  done
  [[ -f .devenv/input-paths.txt ]] || return 0
  while IFS= read -r file; do
    case $file in
      "$root"/.devenv/* | "$root"/.direnv/*) ;;
      "$root"/*) echo "$file" ;;
    esac
  done <.devenv/input-paths.txt
}

# A plugin's FileChanged matcher adds nothing to Claude Code's watch list;
# watchPaths returned by the hook do.
print_watch_paths() {
  local path json=""
  while IFS= read -r path; do
    path=${path//\\/\\\\}
    json+=${json:+,}\"${path//\"/\\\"}\"
  done < <(watch_paths | sort -u)
  printf '{"hookSpecificOutput":{"hookEventName":"%s","watchPaths":[%s]}}\n' "$event" "$json"
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

if [[ -z ${CLAUDE_ENV_FILE-} ]]; then
  say "no devenv environment to export, because CLAUDE_ENV_FILE is not set"
  exit 0
fi
if [[ ! -f $root/devenv.nix ]]; then
  say "no devenv environment to export, because the project has no devenv.nix"
  exit 0
fi
if ! command -v devenv >/dev/null; then
  say "no devenv environment to export, because devenv is not on PATH"
  exit 0
fi

cd "$root"
root=$(pwd -P)
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
  say "kept the previous devenv environment, because the evaluation failed; run devenv shell to see why"
  print_watch_paths
  exit 0
fi
[[ $how == direnv ]] || env=$(import_devenv "$script")

# Replace the file in one step: Claude Code may read it for a command meanwhile.
tmp=$(mktemp "$CLAUDE_ENV_FILE.XXXXXX")
printf '%s\n' "$env" >"$tmp"
mv "$tmp" "$CLAUDE_ENV_FILE"
say "exported the devenv environment through $how"
print_watch_paths
