#!/usr/bin/env bash
set -euo pipefail

built=${1:?usage: agent-identity.sh <the agent-identity that the baseline builds>}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
program=$here/agent-identity.py
manifest=$here/agent-app-manifest.json
tmp=$(mktemp -d)
stub_pid=""
trap '[[ -z $stub_pid ]] || kill "$stub_pid"; rm -rf "$tmp"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GH_TOKEN GIT_CONFIG_COUNT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
failures=0

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

stub=$tmp/stub
lyngon_id=Iv23liLyngonDev
acme_id=Iv23liAcmeDev
for id in "$lyngon_id" "$acme_id"; do
  mkdir -p "$stub/$id" "$tmp/keys"
  openssl genrsa -traditional -out "$tmp/keys/$id.pem" 2048 2>/dev/null
  openssl rsa -in "$tmp/keys/$id.pem" -pubout -out "$stub/$id/public.pem" 2>/dev/null
  chmod 600 "$tmp/keys/$id.pem"
done
mkdir -p "$stub/any"

canned() {
  local caller=$1 method=$2 path=$3 status=$4 body=$5
  printf '{"status": %s, "body": %s}\n' "$status" "$body" >"$stub/$caller/$method ${path//\//|}.json"
}

canned "$lyngon_id" GET /app 200 '{"id": 101, "slug": "lyngon-developer", "name": "Lyngon Developer", "client_id": "'"$lyngon_id"'", "owner": {"login": "lyngon", "type": "Organization"}}'
canned "$acme_id" GET /app 200 '{"id": 202, "slug": "acme-developer", "name": "Acme Developer", "client_id": "'"$acme_id"'", "owner": {"login": "acme", "type": "Organization"}}'
installed() {
  canned "$1" GET /repos/acme/widgets/installation 200 '{"id": '"$2"', "app_id": 1, "target_type": "Organization", "account": {"login": "acme"}}'
}
token_answer() {
  printf '{"token": "%s", "expires_at": "%s", "permissions": %s, "repository_selection": "all"}' "$1" "$2" "$3"
}
granted='{"actions": "read", "checks": "read", "contents": "write", "issues": "write", "metadata": "read", "pull_requests": "write", "statuses": "read", "workflows": "write"}'
for pair in "$lyngon_id:55" "$acme_id:77"; do
  canned "${pair%%:*}" POST "/app/installations/${pair##*:}/access_tokens" 201 "$(token_answer "ghs_minted_${pair##*:}" 2099-01-01T00:00:00Z "$granted")"
done
canned any GET "/users/lyngon-developer%5Bbot%5D" 200 '{"login": "lyngon-developer[bot]", "id": 3131, "type": "Bot"}'
canned any GET "/users/acme-developer%5Bbot%5D" 200 '{"login": "acme-developer[bot]", "id": 4242, "type": "Bot"}'

python3 "$here/tests/github-stub.py" "$stub" "$tmp/port" &
stub_pid=$!
for _ in $(seq 50); do
  [[ ! -s $tmp/port ]] || break
  sleep 0.1
done
api=http://127.0.0.1:$(<"$tmp/port")

wrapper=$tmp/bin/agent-identity
mkdir -p "$tmp/bin"
cat >"$wrapper" <<EOF
#!/usr/bin/env bash
PYTHONPATH="$here" exec python3 "$program" --manifest "$manifest" --enabled "\${STUB_ENABLED:-true}" --program "$wrapper" "\$@"
EOF
chmod +x "$wrapper"

repo=$tmp/widgets
git init -q -b main "$repo"
git -C "$repo" remote add origin git@github.com:acme/widgets.git
git -C "$repo" config user.name "Ada Operator"
git -C "$repo" config user.email ada@example.com

config=$tmp/config
declare_apps() {
  mkdir -p "$config/lyngon"
  : >"$config/lyngon/agent-apps.toml"
  local id
  for id in "$@"; do
    printf '[[app]]\nclient_id = "%s"\nkey_file = "%s"\n\n' "$id" "$tmp/keys/$id.pem" >>"$config/lyngon/agent-apps.toml"
  done
}

run() {
  local variables=() empty_cache
  while [[ $1 != -- ]]; do
    variables+=("$1")
    shift
  done
  shift
  empty_cache=$(mktemp -d "$tmp/runtime.XXXXXX")
  code=0
  out=$(cd "$repo" && env -i PATH="$PATH" HOME="$tmp/home" XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$empty_cache" \
    GITHUB_API_URL="$api" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "${variables[@]}" "$wrapper" "$@" 2>"$tmp/stderr") || code=$?
  err=$(<"$tmp/stderr")
}

how_to=https://github.com/lyngon/devkit/blob/main/devenv/agent-identity.md
python=$(python3 -c 'import sys; print(sys.executable)')

declare_apps "$lyngon_id" "$acme_id"
installed "$lyngon_id" 55
installed "$acme_id" 77
session_runtime=$(mktemp -d "$tmp/runtime.XXXXXX")
run XDG_RUNTIME_DIR="$session_runtime" -- session --root "$repo"
expected_lines="export GIT_AUTHOR_NAME='acme-developer[bot]'
export GIT_AUTHOR_EMAIL='4242+acme-developer[bot]@users.noreply.github.com'
export GIT_COMMITTER_NAME='acme-developer[bot]'
export GIT_COMMITTER_EMAIL='4242+acme-developer[bot]@users.noreply.github.com'
export LYNGON_AGENT_OPERATOR='Ada Operator <ada@example.com>'
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=credential.https://github.com.helper
export GIT_CONFIG_VALUE_0=''
export GIT_CONFIG_KEY_1=credential.https://github.com.helper
export GIT_CONFIG_VALUE_1='!$wrapper git-credential --installation 77 --client-id $acme_id --key-file $tmp/keys/$acme_id.pem'
export GIT_CONFIG_KEY_2=url.https://github.com/.insteadOf
export GIT_CONFIG_VALUE_2=git@github.com:
export GIT_CONFIG_KEY_3=url.https://github.com/.insteadOf
export GIT_CONFIG_VALUE_3=ssh://git@github.com/
export GH_TOKEN=\"\$($python $here/agent_token.py --installation 77 -- $wrapper token --installation 77 --client-id $acme_id --key-file $tmp/keys/$acme_id.pem)\""
check "both installed: the App whose owner owns the repository acts, though declared second" \
  equals "$code|$out" "0|$expected_lines"
check "both installed: the message names the bot and the operator as co-author" \
  equals "$err" "Agent identity: agents in this session act on GitHub as acme-developer[bot], the App Acme Developer, and every commit they make names you, Ada Operator <ada@example.com>, as its co-author. Never unset GH_TOKEN, the GIT_CONFIG_ variables or the git author to act as the operator."
printf '%s\n' "$out" >"$tmp/exports.sh"

# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
read_back() {
  env -i PATH="$PATH" HOME="$tmp/home" XDG_RUNTIME_DIR="$session_runtime" GITHUB_API_URL=http://127.0.0.1:9 \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 bash --norc --noprofile -c 'source "$1"; cd "$2"; eval "$3"' \
    bash "$tmp/exports.sh" "$repo" "$1" 2>&1
}
# shellcheck disable=SC2016  # the shell that reads the lines back expands the script
check "read back: GH_TOKEN is the session's token, from the cache with GitHub out of reach" \
  equals "$(read_back 'printf %s "$GH_TOKEN"')" "ghs_minted_77"
check "read back: git asks agent-identity alone for GitHub's credentials" \
  equals "$(read_back 'printf "protocol=https\nhost=github.com\n\n" | git credential fill')" \
  "protocol=https"$'\n'"host=github.com"$'\n'"username=x-access-token"$'\n'"password=ghs_minted_77"
check "read back: a remote over ssh on GitHub is reached over https" \
  equals "$(read_back 'git ls-remote --get-url origin')" "https://github.com/acme/widgets.git"

built_out=$(cd "$repo" && env -i PATH="$PATH" HOME="$tmp/home" XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$session_runtime" \
  GITHUB_API_URL="$api" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$built" session --root "$repo" 2>/dev/null)
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "the built command: the same bot, and a token line that reads the cache" \
  equals "$(head -n 1 <<<"$built_out")|$(env -i XDG_RUNTIME_DIR="$session_runtime" bash --norc --noprofile -c "$(tail -n 1 <<<"$built_out")"'; printf %s "$GH_TOKEN"')" \
  "export GIT_AUTHOR_NAME='acme-developer[bot]'|ghs_minted_77"

rm "$stub/$acme_id/GET |repos|acme|widgets|installation.json"
canned "$acme_id" GET /app 200 '{"id": 202, "slug": "acme-developer", "name": "Acme Developer", "client_id": "'"$acme_id"'", "owner": {"login": "elsewhere", "type": "Organization"}}'
installed "$acme_id" 77
run -- session --root "$repo"
check "both installed, neither owned by the repository's owner: the first declared acts" \
  equals "$(head -n 1 <<<"$out")" "export GIT_AUTHOR_NAME='lyngon-developer[bot]'"

git -C "$repo" config --unset user.email
run -- session --root "$repo"
check "no user.email: no co-author, and the message says why" \
  equals "$(grep -c LYNGON_AGENT_OPERATOR <<<"$out")|$err" "0|Agent identity: agents in this session act on GitHub as lyngon-developer[bot], the App Lyngon Developer, and their commits name no co-author, because git has no user.name and user.email here. Never unset GH_TOKEN, the GIT_CONFIG_ variables or the git author to act as the operator."
git -C "$repo" config user.email ada@example.com

run STUB_ENABLED=false -- session --root "$repo"
check "option off: no lines, and the message names the option" \
  equals "$out|$err" "|Agent identity: agents act on GitHub as you, the operator, because this repository sets lyngon.agentIdentity.enable = false in devenv.nix."

git -C "$repo" remote set-url origin https://gitlab.com/acme/widgets.git
run -- session --root "$repo"
check "origin off GitHub: no lines, and the message says so" \
  equals "$out|$err" "|Agent identity: agents act on GitHub as you, the operator, because the origin of this repository is not on github.com."
git -C "$repo" remote set-url origin https://github.com/acme/widgets

rm "$config/lyngon/agent-apps.toml"
run -- session --root "$repo"
check "no declaration: no lines, and the message points a newcomer to the how-to" \
  equals "$out|$err" "|Agent identity: agents act on GitHub as you, the operator, because this machine declares no GitHub App for agents in $config/lyngon/agent-apps.toml; to give them an identity of their own, see $how_to."

closed_first_line="export GH_TOKEN=agent-identity-unavailable"
closed_message() {
  echo "Agent identity: agents cannot reach GitHub in this session, because $1. Tell the operator, and never unset GH_TOKEN or the GIT_CONFIG_ variables to act as them. A fix takes effect in a new session. See $how_to"
}

declare_apps "$lyngon_id" "$acme_id"
rm "$stub/$lyngon_id/GET |repos|acme|widgets|installation.json" "$stub/$acme_id/GET |repos|acme|widgets|installation.json"
run -- session --root "$repo"
check "none installed: GitHub is closed to the session" \
  equals "$(head -n 1 <<<"$out")" "$closed_first_line"
check "none installed: the message names each App's install link, the owner and the option" \
  equals "$err" "$(closed_message "no App this machine declares is installed on acme/widgets; its owner acme can install Lyngon Developer (https://github.com/apps/lyngon-developer/installations/new) or Acme Developer (https://github.com/apps/acme-developer/installations/new), or the repository can set lyngon.agentIdentity.enable = false in devenv.nix to let agents act as the operator")"
# shellcheck disable=SC2016  # the inner shell expands the single-quoted script
check "none installed: git gets no credential, and stops asking" \
  equals "$(printf '%s\n' "$out" >"$tmp/closed.sh" && env -i PATH="$PATH" HOME="$tmp/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_TERMINAL_PROMPT=0 bash --norc --noprofile -c 'source "$1"; printf "protocol=https\nhost=github.com\n\n" | git credential fill >/dev/null 2>&1 && echo filled || echo refused' bash "$tmp/closed.sh")" "refused"

installed "$acme_id" 77
chmod 640 "$tmp/keys/$lyngon_id.pem"
run -- session --root "$repo"
check "a key file others can read: closed, naming the file and the fix" \
  equals "$(head -n 1 <<<"$out")|$err" "$closed_first_line|$(closed_message "someone else than you can read the key file $tmp/keys/$lyngon_id.pem of the App $lyngon_id (mode 640); make it yours alone with chmod 600")"
chmod 600 "$tmp/keys/$lyngon_id.pem"

canned "$acme_id" POST /app/installations/77/access_tokens 201 "$(token_answer ghs_wide 2099-01-01T00:00:00Z '{"administration": "write", "contents": "write", "metadata": "read"}')"
run -- session --root "$repo"
check "a token with a permission the template does not grant: closed, naming it" \
  equals "$(head -n 1 <<<"$out")|$err" "$closed_first_line|$(closed_message "the App $acme_id holds administration: write, which its manifest template does not grant; an owner must take the permission back on GitHub, or add it to the template first")"
canned "$acme_id" POST /app/installations/77/access_tokens 201 "$(token_answer ghs_minted_77 2099-01-01T00:00:00Z "$granted")"

run GITHUB_API_URL=http://127.0.0.1:9 -- session --root "$repo"
check "GitHub out of reach: closed, saying so" \
  grep -qF "because GitHub could not be reached at http://127.0.0.1:9" <<<"$err"

cache=$(mktemp -d "$tmp/runtime.XXXXXX")
mkdir -m 700 "$cache/lyngon-agent-identity"
token_answer ghs_cached "$(date -u -d '+4 minutes' +%Y-%m-%dT%H:%M:%SZ)" "$granted" >"$cache/lyngon-agent-identity/installation-77.json"
run XDG_RUNTIME_DIR="$cache" -- token --installation 77 --client-id "$acme_id" --key-file "$tmp/keys/$acme_id.pem"
check "a cached token with less than five minutes left: a new one is minted" \
  equals "$code|$out" "0|ghs_minted_77"
check "the cache is readable by its owner alone" \
  equals "$(stat -c %a "$cache/lyngon-agent-identity")|$(stat -c %a "$cache/lyngon-agent-identity/installation-77.json")" "700|600"

token_answer ghs_cached 2099-01-01T00:00:00Z "$granted" >"$cache/lyngon-agent-identity/installation-77.json"
run XDG_RUNTIME_DIR="$cache" GITHUB_API_URL=http://127.0.0.1:9 -- token --installation 77 --client-id "$acme_id" --key-file "$tmp/keys/$acme_id.pem"
check "a cached token with time left: used, with GitHub out of reach" \
  equals "$code|$out" "0|ghs_cached"

token_line() {
  env -i PATH="$PATH" HOME="$tmp/home" XDG_RUNTIME_DIR="$cache" GITHUB_API_URL="$api" \
    python3 "$here/agent_token.py" --installation 77 -- "$wrapper" token "$@" 2>&1
}
check "agent_token.py with time left: the cached token, without the command" \
  equals "$(token_line)" "ghs_cached"
token_answer ghs_cached "$(date -u -d '+4 minutes' +%Y-%m-%dT%H:%M:%SZ)" "$granted" >"$cache/lyngon-agent-identity/installation-77.json"
check "agent_token.py with less than five minutes left: the command runs and mints" \
  equals "$(token_line --installation 77 --client-id "$acme_id" --key-file "$tmp/keys/$acme_id.pem")" "ghs_minted_77"

run -- token
check "token without an installation: the value GitHub rejects, and the reason" \
  equals "$code|$out|$err" "1|agent-identity-unavailable|agent-identity: agents cannot reach GitHub, because no App this machine declares can serve this session. See $how_to"

code=0
out=$(printf 'protocol=https\nhost=github.com\n\n' | env -i PATH="$PATH" HOME="$tmp/home" "$wrapper" git-credential store 2>&1) || code=$?
check "git-credential store: nothing to keep, nothing printed" equals "$code|$out" "0|"

canned any GET /users/acme 200 '{"login": "acme", "id": 9, "type": "Organization"}'
canned any POST /app-manifests/the-code/conversions 201 '{"id": 202, "slug": "acme-developer", "name": "Acme Developer", "client_id": "'"$acme_id"'", "pem": "-----BEGIN RSA PRIVATE KEY-----\nfixture\n-----END RSA PRIVATE KEY-----\n", "owner": {"login": "acme"}}'

cat >"$tmp/browser.py" <<'EOF'
import html, json, pathlib, re, sys, urllib.parse, urllib.request
page = urllib.request.urlopen(sys.argv[1]).read().decode()
action = html.unescape(re.search(r'action="([^"]*)"', page).group(1))
manifest = json.loads(html.unescape(re.search(r'name="manifest" value="([^"]*)"', page).group(1)))
pathlib.Path(sys.argv[2]).write_text(json.dumps({"action": action, "manifest": manifest}))
state = urllib.parse.parse_qs(urllib.parse.urlsplit(action).query)["state"][0]
urllib.request.urlopen(manifest["redirect_url"] + "?" + urllib.parse.urlencode({"code": "the-code", "state": state})).read()
EOF
# It works in the background, as a browser does, since webbrowser waits for its
# command.
cat >"$tmp/browser" <<EOF
#!/usr/bin/env bash
python3 "$tmp/browser.py" "\$1" "$tmp/posted.json" >/dev/null 2>&1 &
EOF
chmod +x "$tmp/browser"

run BROWSER="$tmp/browser" -- create-app --name "Acme Developer" --owner acme --public --key-file "$tmp/new-key.pem"
check "create-app: exits 0 and prints the install link and the declaration" \
  equals "$code|$(tail -n 8 <<<"$out")" "0|1. Install it on the repositories its agents work in: https://github.com/apps/acme-developer/installations/new
2. Keep the key where only you can read it, and declare the App in $config/lyngon/agent-apps.toml:

[[app]]
client_id = \"$acme_id\"
key_file = \"$tmp/new-key.pem\"

See $how_to"
check "create-app: the key is in the new file, readable by its owner alone" \
  equals "$(stat -c %a "$tmp/new-key.pem")|$(head -n 1 "$tmp/new-key.pem")" "600|-----BEGIN RSA PRIVATE KEY-----"
check "create-app: the page posts to the organization's new App form, with the state" \
  python3 -c 'import json, sys; a = json.load(open(sys.argv[1]))["action"]; sys.exit(not a.startswith("https://github.com/organizations/acme/settings/apps/new?state="))' "$tmp/posted.json"
check "create-app: the manifest is the template with the name, public and the way back filled in" \
  python3 -c 'import json, sys
posted = json.load(open(sys.argv[1]))["manifest"]
template = json.load(open(sys.argv[2]))
back = posted.pop("redirect_url")
sys.exit(not (posted == {**template, "name": "Acme Developer", "public": True} and back.startswith("http://127.0.0.1:") and back.endswith("/callback")))' "$tmp/posted.json" "$manifest"

run BROWSER="$tmp/browser" -- create-app --name "Acme Developer" --owner acme --key-file "$tmp/new-key.pem"
check "create-app over an existing key file: refuses and keeps the file" \
  equals "$code|$(head -n 1 "$tmp/new-key.pem")" "1|-----BEGIN RSA PRIVATE KEY-----"

co_author() {
  env -i PATH="$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$@" \
    bash "$here/co-author-operator.sh" "$tmp/message"
}
printf 'feat: a change\n\nThe body.\n' >"$tmp/message"
co_author LYNGON_AGENT_OPERATOR="Ada Operator <ada@example.com>"
check "co-author: an agent session's commit names the operator in a trailer" \
  equals "$(<"$tmp/message")" $'feat: a change\n\nThe body.\n\nCo-authored-by: Ada Operator <ada@example.com>'
co_author LYNGON_AGENT_OPERATOR="Ada Operator <ada@example.com>"
check "co-author: an amended commit keeps one trailer" \
  equals "$(grep -c '^Co-authored-by:' "$tmp/message")" "1"
printf 'feat: a change\n' >"$tmp/message"
co_author
check "co-author: a commit outside an agent session stays as it is" \
  equals "$(<"$tmp/message")" "feat: a change"

if ((failures > 0)); then
  echo "agent identity tests: $failures failure(s)" >&2
  exit 1
fi
echo "agent identity tests: ok"
