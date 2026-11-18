#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
evals=$(dirname "$case_dir")
opentofu=$evals/live-mutation-waits-for-opentofu-on-a-protected-root
tool=$evals/../skills/live-mutation/scripts/live-mutation.py
# shellcheck disable=SC2016  # The backticks are those of the tool's output, matched as text.
digest_line='at digest `([0-9a-f]+)`'

bash "$opentofu/seed-workspace.sh" \
  --no-pull-request \
  --main-files "$evals/live-mutation-runs-opentofu-on-an-unprotected-root/planted"

export CLAUDE_CODE_SESSION_ID=20261110-0900-4000-8000-000000000150
export PATH="$PWD/.git/forge/bin:$PATH"
proposed=$("$tool" propose debug-staging-logs --opentofu infra/staging)
[[ $proposed =~ $digest_line ]]
"$tool" run debug-staging-logs "${BASH_REMATCH[1]}" >/dev/null
