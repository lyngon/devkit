#!/usr/bin/env bash
# Seed the run's empty working directory as the case
# live-mutation-runs-opentofu-on-an-unprotected-root does, but with no pull
# request, and apply the branch to staging as a session that ended before the
# branch had one leaves it: the head's live-mutation.py ran the OpenTofu
# proposal without a go-ahead in a session of its own, and its action record
# waits for the pull request.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
evals=$(dirname "$case_dir")
opentofu=$evals/live-mutation-waits-for-opentofu-on-a-protected-root
tool=$evals/../skills/live-mutation/scripts/live-mutation.py
# shellcheck disable=SC2016  # The backticks are those of the tool's output, matched as text.
digest_line='at digest `([0-9a-f]+)`'

bash "$opentofu/seed-workspace.sh" \
  "feat(infra): log at debug level in staging" "$opentofu/branch" none \
  "$evals/live-mutation-runs-opentofu-on-an-unprotected-root/planted"

export CLAUDE_CODE_SESSION_ID=20261110-0900-4000-8000-000000000150
export PATH="$PWD/.git/forge/bin:$PATH"
proposed=$("$tool" propose debug-staging-logs --opentofu infra/staging)
[[ $proposed =~ $digest_line ]]
"$tool" run debug-staging-logs "${BASH_REMATCH[1]}" >/dev/null
